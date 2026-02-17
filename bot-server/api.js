const express = require('express');
const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs');
const os = require('os');
const {
  ensureWarmPool,
  getWarmPoolStatus,
  assignWarmJobs,
  stopWarmJobs,
  getWarmJobsStatus
} = require('./warmPool');

// Load .env for bot-server when running locally (docker-compose already injects env)
require('dotenv').config();

const execAsync = promisify(exec);

const app = express();
const PORT = process.env.BOT_SERVER_PORT || 3001;

app.use(express.json());

const inFlightJobs = new Map();

function isTrue(val) {
  if (val === true) return true;
  if (val === false || val == null) return false;
  return ['1', 'true', 'yes', 'y', 'on'].includes(String(val).toLowerCase());
}

function buildContainerIds(meetingId, requestId, totalBots) {
  const ids = [];
  for (let i = 1; i <= totalBots; i++) {
    ids.push(`zoom-bot-${meetingId}-${requestId}-${i}`);
  }
  return ids;
}

function shellQuote(value) {
  const str = value == null ? '' : String(value);
  return `'${str.replace(/'/g, `'\"'\"'`)}'`;
}

function toNumber(value, fallback = null) {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readCpuSample() {
  try {
    const stat = fs.readFileSync('/proc/stat', 'utf8');
    const firstLine = stat.split('\n')[0];
    if (!firstLine || !firstLine.startsWith('cpu ')) return null;
    const fields = firstLine.trim().split(/\s+/).slice(1).map((v) => Number.parseInt(v, 10));
    if (!fields.length || fields.some((v) => !Number.isFinite(v))) return null;
    const idle = fields[3] + (fields[4] || 0); // idle + iowait
    const total = fields.reduce((sum, v) => sum + v, 0);
    return { idle, total };
  } catch {
    return null;
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getCpuUsagePercent(sampleMs = 250) {
  const start = readCpuSample();
  if (!start) return null;
  await delay(sampleMs);
  const end = readCpuSample();
  if (!end) return null;

  const totalDelta = end.total - start.total;
  const idleDelta = end.idle - start.idle;
  if (totalDelta <= 0) return null;

  const usage = ((totalDelta - idleDelta) / totalDelta) * 100;
  if (!Number.isFinite(usage)) return null;
  return Math.max(0, Math.min(100, usage));
}

function parseBotIndexFromName(name) {
  const match = String(name || '').match(/-(\d+)$/);
  return match ? Number.parseInt(match[1], 10) : Number.MAX_SAFE_INTEGER;
}

function isWarmDirectAssignConfigured() {
  const prebuiltRuntime = isTrue(process.env.BOT_PREBUILT_RUNTIME);
  const directAssign = isTrue(process.env.BOT_WARM_POOL_DIRECT_ASSIGN ?? 'true');
  const poolSize = Number.parseInt(process.env.BOT_WARM_POOL_SIZE || '0', 10) || 0;
  return prebuiltRuntime && directAssign && poolSize > 0;
}

async function startComposeServices(projectDir, composeFilePath, staggerMs = 0, selectedServices = null) {
  const dockerEnv = {
    ...process.env,
    DOCKER_HOST: 'unix:///var/run/docker.sock'
  };

  const serviceFilter = Array.isArray(selectedServices)
    ? selectedServices.map((s) => String(s || '').trim()).filter(Boolean)
    : null;
  if (serviceFilter && serviceFilter.length === 0) {
    return;
  }

  const safeStaggerMs = Number.isFinite(staggerMs) && staggerMs > 0 ? Math.floor(staggerMs) : 0;
  if (safeStaggerMs <= 0) {
    const serviceArgs = serviceFilter ? ` ${serviceFilter.map((s) => shellQuote(s)).join(' ')}` : '';
    const startCommand = `docker-compose -f "${composeFilePath}" up -d --force-recreate${serviceArgs}`;
    return execAsync(startCommand, { cwd: projectDir, env: dockerEnv, shell: '/bin/sh' });
  }

  let services = serviceFilter ? [...serviceFilter] : [];
  if (!serviceFilter) {
    try {
      const { stdout: servicesOut } = await execAsync(
        `docker-compose -f "${composeFilePath}" config --services`,
        { cwd: projectDir, env: dockerEnv, shell: '/bin/sh' }
      );
      services = (servicesOut || '').split('\n').map((s) => s.trim()).filter(Boolean);
    } catch (error) {
      console.warn(`⚠️ Could not list services for staggered start, falling back to bulk start: ${error.message}`);
    }
  }

  if (!services.length) {
    const fallbackCommand = `docker-compose -f "${composeFilePath}" up -d --force-recreate`;
    return execAsync(fallbackCommand, { cwd: projectDir, env: dockerEnv, shell: '/bin/sh' });
  }

  console.log(`🚦 Starting ${services.length} services with stagger ${safeStaggerMs}ms`);
  for (let i = 0; i < services.length; i++) {
    const service = services[i];
    const upCommand = `docker-compose -f "${composeFilePath}" up -d --no-deps --force-recreate ${shellQuote(service)}`;
    await execAsync(upCommand, { cwd: projectDir, env: dockerEnv, shell: '/bin/sh' });
    if (i < services.length - 1) {
      await delay(safeStaggerMs);
    }
  }
}

async function getComposeServiceSpecs(projectDir, composeFilePath) {
  const dockerEnv = {
    ...process.env,
    DOCKER_HOST: 'unix:///var/run/docker.sock'
  };

  const { stdout } = await execAsync(
    `docker-compose -f "${composeFilePath}" config --format json`,
    { cwd: projectDir, env: dockerEnv, shell: '/bin/sh' }
  );

  const config = JSON.parse(stdout || '{}');
  const services = config.services || {};
  const specs = Object.entries(services).map(([serviceName, service]) => ({
    serviceName,
    containerName: service.container_name || '',
    command: Array.isArray(service.command) ? service.command : [],
    environment: service.environment && typeof service.environment === 'object' ? service.environment : {},
    workingDir: service.working_dir || '/tmp/meeting-sdk-linux-sample'
  }));

  return specs
    .filter((spec) => spec.containerName)
    .sort((a, b) => parseBotIndexFromName(a.containerName) - parseBotIndexFromName(b.containerName));
}

async function startBotsWithWarmPool(projectDir, composeFilePath, meetingId, requestId, totalBots, staggerMs = 0) {
  if (!isWarmDirectAssignConfigured()) {
    await startComposeServices(projectDir, composeFilePath, staggerMs);
    return {
      assignedIds: [],
      fallbackServiceNames: [],
      containerIds: buildContainerIds(meetingId, requestId, totalBots)
    };
  }

  const specs = await getComposeServiceSpecs(projectDir, composeFilePath);
  if (!specs.length) {
    throw new Error(`No services found in compose file: ${composeFilePath}`);
  }

  const jobSpecs = specs.map((spec) => ({
    ...spec,
    jobId: spec.containerName,
    meetingId,
    requestId
  }));

  const { assigned, unassigned } = await assignWarmJobs(jobSpecs);
  const assignedIds = assigned.map((entry) => entry.jobId);
  const fallbackServices = unassigned.map((entry) => entry.serviceName);

  if (fallbackServices.length > 0) {
    await startComposeServices(projectDir, composeFilePath, staggerMs, fallbackServices);
  }

  return {
    assignedIds,
    fallbackServiceNames: fallbackServices,
    containerIds: jobSpecs.map((job) => job.jobId)
  };
}

/**
 * POST /api/bots/create - Create bots on this server
 */
app.post('/api/bots/create', async (req, res) => {
  try {
    // Log full request body for debugging
    console.log('📥 Received request body:', JSON.stringify(req.body, null, 2));
    
    const { 
      meetingId, 
      requestId, // Unique ID for this bot creation request (timestamp)
      password, 
      joinUrl, 
      videoCount, 
      audioCount, 
      nameType, 
      meetingType,
      accountId,
      clientId,
      clientSecret,
      timeoutSeconds,
      useSingleZak,  // true = 1 ZAK for all bots (fast), false = per-user ZAK
      videoFile,
      staggerMs
    } = req.body;
    
    // Generate request ID if not provided (backward compatibility)
    const uniqueRequestId = requestId || Date.now().toString();
    
    // Log extracted values
    console.log('📋 Extracted values:', {
      meetingId,
      requestId: uniqueRequestId,
      password: password ? '***' : undefined,
      joinUrl,
      videoCount,
      audioCount,
      nameType,
      meetingType,
      accountId: accountId ? '***' : undefined,
      clientId: clientId ? '***' : undefined,
      clientSecret: clientSecret ? '***' : undefined,
      timeoutSeconds,
      videoFile
    });
    
    // Validate required fields
    if (!meetingId || !password || !joinUrl) {
      return res.status(400).json({ 
        error: 'Missing required fields: meetingId, password, or joinUrl' 
      });
    }
    
    // Validate videoCount and audioCount are provided and are numbers
    if (videoCount === undefined || audioCount === undefined) {
      return res.status(400).json({ 
        error: 'Missing required fields: videoCount or audioCount',
        received: { videoCount, audioCount }
      });
    }
    
    // Ensure videoCount and audioCount are numbers
    // Handle undefined/null/NaN explicitly
    // Also check if values are strings that look like numbers
    let video = 0;
    let audio = 0;
    
    // Check if videoCount is actually a number (not a string like 'Indian')
    if (videoCount !== undefined && videoCount !== null) {
      // If it's a string that's not a number, it might be mis-assigned
      if (typeof videoCount === 'string' && isNaN(parseInt(videoCount, 10))) {
        console.error('⚠️ videoCount appears to be mis-assigned:', videoCount);
        console.error('⚠️ Full request body:', JSON.stringify(req.body, null, 2));
        // Try to find videoCount in the request body by checking all numeric values
        const numericValues = Object.values(req.body).filter(v => typeof v === 'number' || (typeof v === 'string' && !isNaN(parseInt(v, 10))));
        console.error('⚠️ Numeric values found in request:', numericValues);
      }
      video = parseInt(videoCount, 10);
      if (isNaN(video)) video = 0;
    }
    
    if (audioCount !== undefined && audioCount !== null) {
      // If it's a string that's not a number, it might be mis-assigned
      if (typeof audioCount === 'string' && isNaN(parseInt(audioCount, 10))) {
        console.error('⚠️ audioCount appears to be mis-assigned:', audioCount);
      }
      audio = parseInt(audioCount, 10);
      if (isNaN(audio)) audio = 0;
    }
    
    // Validate that we have valid numbers
    if (video < 0 || audio < 0 || (video === 0 && audio === 0)) {
      console.error('❌ Invalid videoCount or audioCount:', { 
        videoCount, 
        audioCount, 
        video, 
        audio,
        videoCountType: typeof videoCount,
        audioCountType: typeof audioCount,
        fullBody: req.body
      });
      return res.status(400).json({ 
        error: 'Invalid videoCount or audioCount',
        details: { 
          videoCount, 
          audioCount, 
          parsed: { video, audio },
          receivedBody: req.body
        },
        message: 'Both videoCount and audioCount must be non-negative numbers, and at least one must be greater than 0'
      });
    }
    
    const totalBotsForLog = video + audio;
    const totalBots = totalBotsForLog;
    const zakTimeEst = meetingType === 'Profile Pic Member' 
      ? Math.ceil(totalBotsForLog / 20) + 5  // ~20 parallel, +5s overhead
      : 0;
    console.log(`Creating bots: ${video} video, ${audio} audio`);
    console.log(`⏳ Estimated time: ~${zakTimeEst + Math.ceil(totalBotsForLog / 10) + 15}s (ZAK ${zakTimeEst}s + containers ~${Math.ceil(totalBotsForLog/10)}s)`);

    if (isTrue(process.env.BOT_WARM_POOL_AUTO_REFILL_ON_CREATE)) {
      ensureWarmPool()
        .then((status) => {
          if (status.enabled) {
            console.log(`🔥 Warm pool ready: ${status.running}/${status.targetSize}`);
          }
        })
        .catch((poolErr) => {
          console.warn(`⚠️ Warm pool check failed: ${poolErr.message}`);
        });
    }
    
    // Get project directory
    // In Docker: mounted at /app/bot-project
    // Local: parent directory
    const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
    
    // Verify script exists
    const scriptPath = path.join(projectDir, 'setup-flexible-bots.sh');
    const fs = require('fs');
    if (!fs.existsSync(scriptPath)) {
      return res.status(500).json({ 
        error: 'Bot setup script not found',
        message: `Script not found at: ${scriptPath}. Project dir: ${projectDir}`,
        files: fs.readdirSync(projectDir).slice(0, 10)
      });
    }
    
    // Calculate name offset: count existing containers for this meeting
    // This ensures names continue from where we left off, avoiding duplicates
    let nameOffset = 0;
    try {
      const { stdout: existingContainers } = await execAsync(
        `docker ps -a --filter "name=zoom-bot-${meetingId}-" --format "{{.Names}}"`,
        { cwd: projectDir, shell: '/bin/sh' }
      );
      if (existingContainers && existingContainers.trim()) {
        const containerNames = existingContainers.trim().split('\n').filter(n => n);
        nameOffset = containerNames.length;
        console.log(`📊 Found ${nameOffset} existing containers for meeting ${meetingId}, using name offset: ${nameOffset}`);
      }
    } catch (error) {
      console.log(`ℹ️  Could not count existing containers, starting from name offset 0`);
    }
    
    // Build command to run setup-flexible-bots.sh
    // Use bash explicitly and make scripts executable
    // Pass HOST_PROJECT_PATH so generate-flexible-bots.sh can use it in volume mounts
    // Pass meetingType to determine if ZAK tokens should be generated
    // Pass nameType to determine which names file to use (Indian/International)
    // Pass meetingId and requestId for unique container names and compose file names
    // requestId ensures each bot creation request gets its own compose file, even for same meeting
    // Pass NAME_OFFSET to continue names from where we left off (prevents duplicates)
    const hostPath = process.env.HOST_PROJECT_PATH || '/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample';
    // Quote projectDir to handle paths with spaces
    const useSingleZakEnv = (useSingleZak === true || useSingleZak === 'true') ? 'true' : 'false';
    const timeoutSecs = parseInt(timeoutSeconds, 10) || 7200;
    const startStaggerMs = Math.max(0, parseInt(staggerMs ?? process.env.BOT_START_STAGGER_MS ?? process.env.BOT_STAGGER_MS ?? '0', 10) || 0);
    console.log(`⏱️  Timeout: ${timeoutSecs}s (from request: ${timeoutSeconds}, bots will leave meeting after this)`);
    if (startStaggerMs > 0) {
      console.log(`🚦 Container start stagger enabled: ${startStaggerMs}ms`);
    }
    // Pass timeout as 9th arg (reliable in Docker/exec); env TIMEOUT_SECONDS may not propagate
    const videoFileEnv = (typeof videoFile === 'string' && videoFile.trim().length > 0) ? videoFile.trim() : '';
    const resolvedAccountId = (typeof accountId === 'string' && accountId.trim()) || (process.env.ZOOM_ACCOUNT_ID || '').trim();
    const resolvedClientId = (typeof clientId === 'string' && clientId.trim()) || (process.env.ZOOM_CLIENT_ID || '').trim();
    const resolvedClientSecret = (typeof clientSecret === 'string' && clientSecret.trim()) || (process.env.ZOOM_CLIENT_SECRET || '').trim();

    if (meetingType === 'Profile Pic Member' && (!resolvedAccountId || !resolvedClientId || !resolvedClientSecret)) {
      return res.status(400).json({
        error: 'Missing Zoom credentials for Profile Pic Member',
        message: 'accountId, clientId, and clientSecret are required for ZAK generation.'
      });
    }

    const command = `cd "${projectDir}" && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && VIDEO_FILE=${shellQuote(videoFileEnv)} MEETING_TYPE=${shellQuote(meetingType)} NAME_TYPE=${shellQuote(nameType)} NAME_OFFSET=${nameOffset} USE_SINGLE_ZAK=${useSingleZakEnv} bash setup-flexible-bots.sh ${video} ${audio} ${shellQuote(joinUrl)} ${shellQuote(resolvedAccountId)} ${shellQuote(resolvedClientId)} ${shellQuote(resolvedClientSecret)} ${shellQuote(meetingId)} ${shellQuote(uniqueRequestId)} ${timeoutSecs}`;
    const composeFileName = `compose-${meetingId}-${uniqueRequestId}-bots.yaml`;
    const composeFilePath = path.join(projectDir, composeFileName);

    const asyncMode = req.body?.async !== undefined
      ? isTrue(req.body?.async)
      : isTrue(process.env.BOT_CREATE_ASYNC ?? 'true');
    if (asyncMode) {
      const containerIds = buildContainerIds(meetingId, uniqueRequestId, totalBots);
      res.status(202).json({
        success: true,
        message: `Bot creation started (${video} video, ${audio} audio)`,
        requestId: uniqueRequestId,
        containerIds,
        videoCount: video,
        audioCount: audio
      });

      inFlightJobs.set(uniqueRequestId, { meetingId, totalBots, startedAt: Date.now() });
      exec(command, {
        cwd: projectDir,
        env: { ...process.env, DOCKER_HOST: 'unix:///var/run/docker.sock' },
        shell: '/bin/sh',
        maxBuffer: 1024 * 1024
      }, async (err, stdout, stderr) => {
        try {
          if (err) {
            console.error('❌ Async bot creation setup failed:', err.message);
            if (stderr) console.error('Async stderr:', stderr);
            return;
          }

          if (!fs.existsSync(composeFilePath)) {
            console.error(`❌ Async bot creation failed: compose file not found at ${composeFilePath}`);
            return;
          }

          const warmResult = await startBotsWithWarmPool(
            projectDir,
            composeFilePath,
            meetingId,
            uniqueRequestId,
            totalBots,
            startStaggerMs
          );
          console.log(`✅ Async bot creation finished (warm-assigned: ${warmResult.assignedIds.length}, compose-fallback: ${warmResult.fallbackServiceNames.length})`);
        } catch (startError) {
          console.error('❌ Async bot creation failed:', startError.message);
          if (startError.stdout) console.error('Async stdout:', startError.stdout);
          if (startError.stderr) console.error('Async stderr:', startError.stderr);
        } finally {
          inFlightJobs.delete(uniqueRequestId);
        }
      });
      return;
    }
    
    // Execute setup script
    // With parallel ZAK: ~20s for 150 bots. Container startup: ~2-3s per 10 containers
    const scriptTimeout = Math.max(180000, totalBots * 5000); // 5s per bot (parallel ZAK), min 3 min
    
    // Validate timeout is a valid number
    if (isNaN(scriptTimeout) || scriptTimeout <= 0) {
      console.error('Invalid scriptTimeout calculated:', { video, audio, totalBots, scriptTimeout });
      return res.status(500).json({ 
        error: 'Failed to calculate script timeout',
        details: { video, audio, totalBots, scriptTimeout }
      });
    }
    
    console.log(`⏳ Executing setup script (timeout: ${scriptTimeout/1000}s)...`);
    console.log(`   Step 1: Checking/ensuring zoom-bot:latest image exists...`);
    
    // Check if zoom-bot:latest image exists, if not, we'll need to build it
    // But building from inside container has path issues on Mac, so we skip for now
    // User should build image separately: docker build -t zoom-bot:latest .
    try {
      await execAsync('docker images zoom-bot:latest --format "{{.Repository}}:{{.Tag}}"', {
        cwd: projectDir,
        shell: '/bin/sh'
      });
      console.log(`   ✅ Image zoom-bot:latest found`);
    } catch (error) {
      console.log(`   ⚠️  Image zoom-bot:latest not found - containers will fail to start`);
      console.log(`   💡 Build image first: docker build -t zoom-bot:latest .`);
    }
    
    console.log(`   Step 2: Generating compose file...`);
    console.log(`   Step 3: Generating ZAK tokens (${video + audio} bots, ~2s each)...`);
    console.log(`   Step 4: Starting containers...`);
    
    let stdout, stderr;
    try {
      const result = await execAsync(command, {
        cwd: projectDir,
        timeout: scriptTimeout,
        shell: '/bin/sh' // Explicitly specify shell
      });
      stdout = result.stdout;
      stderr = result.stderr;
    } catch (scriptError) {
      // Script execution failed - log detailed error
      console.error('❌ Script execution failed:', scriptError.message);
      console.error('   Command:', command);
      console.error('   Stdout:', scriptError.stdout || '');
      console.error('   Stderr:', scriptError.stderr || '');
      
      // Check if compose file was generated despite error
      if (fs.existsSync(composeFilePath)) {
        console.log(`✅ Compose file was generated: ${composeFilePath}`);
        // Continue with container startup even if script had warnings
        stdout = scriptError.stdout || '';
        stderr = scriptError.stderr || '';
      } else {
        // Script failed and no compose file - throw error
        throw new Error(`Script execution failed: ${scriptError.message}. Compose file not generated.`);
      }
    }
    
    console.log(`✅ Setup script completed`);
    console.log(`📋 Script output:`);
    console.log(stdout);
    
    if (stderr && !stderr.includes('Warning')) {
      console.error('Setup script stderr:', stderr);
    }
    
    // Debug: Check what compose files were generated
    try {
      const { stdout: composeFiles } = await execAsync(`ls -la "${projectDir}"/compose-*-bots.yaml 2>/dev/null || echo 'No compose files found'`, {
        cwd: projectDir,
        shell: '/bin/sh'
      });
      console.log(`📋 Generated compose files:`, composeFiles);
    } catch (error) {
      console.log(`⚠️  Could not list compose files:`, error.message);
    }
    
    // Use meeting ID + request ID for unique compose file name
    // This ensures each bot creation request gets its own compose file
    // composeFileName/composeFilePath already set above
    console.log(`📋 Expected compose file: ${composeFileName}`);
    console.log(`📋 Meeting ID: ${meetingId}`);
    console.log(`📋 Request ID: ${uniqueRequestId}`);
    console.log(`📋 This ensures unique compose file even for same meeting`);
    
    // Verify compose file exists before trying to use it
    if (!fs.existsSync(composeFilePath)) {
      console.error(`❌ Compose file not found: ${composeFilePath}`);
      console.error(`   Checking for any compose files...`);
      try {
        const { stdout: allComposeFiles } = await execAsync(`ls -la "${projectDir}"/compose-*.yaml 2>/dev/null || echo 'No compose files found'`, {
          cwd: projectDir,
          shell: '/bin/sh'
        });
        console.error(`   Found compose files:`, allComposeFiles);
      } catch (error) {
        console.error(`   Could not list compose files:`, error.message);
      }
      return res.status(500).json({ 
        error: 'Compose file not generated',
        message: `Expected compose file ${composeFileName} not found after script execution`,
        meetingId,
        composeFileName,
        projectDir
      });
    }
    console.log(`✅ Compose file exists: ${composeFilePath}`);
    // Start containers / warm workers
    console.log(`🚀 Starting containers...`);
    
    // IMPORTANT: Use container path for docker-compose
    // The compose file is in the container at /app/bot-project/compose-{meetingId}-{requestId}-bots.yaml
    // docker-compose will use the host Docker daemon via socket
    // Force recreate to ensure containers use latest compose file with ZAK tokens
    // Note: --force-recreate will only recreate containers defined in this compose file
    // Other meetings' containers will remain untouched
    // Use full path to ensure docker-compose finds the file
    const startCommand = `docker-compose -f "${composeFilePath}" up -d --force-recreate`;
    
    console.log(`📋 Using compose file: "${projectDir}/${composeFileName}"`);
    console.log(`📋 Full compose file path: ${composeFilePath}`);
    if (startStaggerMs > 0) {
      console.log(`📋 Start mode: staggered (${startStaggerMs}ms between services)`);
    } else {
      console.log(`📋 Command to execute: ${startCommand}`);
    }
    console.log(`📋 Meeting ID: ${meetingId}, Request ID: ${uniqueRequestId}`);
    console.log(`📋 Containers: zoom-bot-${meetingId}-${uniqueRequestId}-1 to zoom-bot-${meetingId}-${uniqueRequestId}-${totalBots}`);
    console.log(`📋 Each request gets unique containers, no conflicts with existing bots`);
    
    // Double-check compose file exists
    if (!fs.existsSync(composeFilePath)) {
      const errorMsg = `Compose file ${composeFileName} does not exist at ${composeFilePath}`;
      console.error(`❌ ${errorMsg}`);
      return res.status(500).json({ 
        error: 'Compose file not found',
        message: errorMsg,
        meetingId,
        composeFileName,
        composeFilePath,
        projectDir
      });
    }
    
    let containerIds = [];
    try {
      const warmResult = await startBotsWithWarmPool(
        projectDir,
        composeFilePath,
        meetingId,
        uniqueRequestId,
        totalBots,
        startStaggerMs
      );
      containerIds = warmResult.containerIds;
      console.log(`🔥 Warm assigned: ${warmResult.assignedIds.length}, compose fallback: ${warmResult.fallbackServiceNames.length}`);
    } catch (dockerError) {
      // Docker-compose command failed - log detailed error
      console.error('❌ Docker-compose command failed:');
      console.error('   Command:', startCommand);
      console.error('   Working directory:', projectDir);
      console.error('   Compose file name:', composeFileName);
      console.error('   Compose file path:', composeFilePath);
      console.error('   Compose file exists:', fs.existsSync(composeFilePath));
      console.error('   Meeting ID:', meetingId);
      console.error('   Request ID:', uniqueRequestId);
      console.error('   Error:', dockerError.message);
      console.error('   Stdout:', dockerError.stdout || '');
      console.error('   Stderr:', dockerError.stderr || '');
      
      // List all compose files to help debug
      try {
        const { stdout: allComposeFiles } = await execAsync(`ls -la "${projectDir}"/compose-*.yaml 2>/dev/null || echo 'No compose files found'`, {
          cwd: projectDir,
          shell: '/bin/sh'
        });
        console.error('   All compose files in directory:', allComposeFiles);
      } catch (listError) {
        console.error('   Could not list compose files:', listError.message);
      }
      
      // Check if compose file exists
      if (!fs.existsSync(composeFilePath)) {
        throw new Error(`Compose file ${composeFileName} does not exist at ${composeFilePath}. Expected format: compose-${meetingId}-${uniqueRequestId}-bots.yaml. Script may have failed to generate it.`);
      }
      
      // Re-throw with better error message
      throw new Error(`Docker-compose failed: ${dockerError.message}. Command: ${startCommand}. Compose file: ${composeFilePath}`);
    }
    
    res.json({
      success: true,
      message: `Created ${totalBots} bots (${video} video, ${audio} audio)`,
      containerIds,
      videoCount: video,
      audioCount: audio
    });
  } catch (error) {
    console.error('Error creating bots:', error);
    res.status(500).json({ 
      error: 'Failed to create bots',
      message: error.message 
    });
  }
});

/**
 * POST /api/bots/containers-status - Check which containers are still running
 * Used by API to auto-update meeting status when bots leave (e.g. timeout)
 */
app.post('/api/bots/containers-status', async (req, res) => {
  try {
    let { containerIds } = req.body;
    console.log('[STATUS] Request. containerIds type:', typeof containerIds, 'isArray:', Array.isArray(containerIds), 'len:', Array.isArray(containerIds) ? containerIds.length : 0);
    if (!containerIds || !Array.isArray(containerIds)) {
      return res.status(400).json({ error: 'containerIds array required' });
    }
    containerIds = containerIds.map(id => String(id).trim()).filter(id => id && id.startsWith('zoom-bot-'));
    console.log('[STATUS] After filter:', containerIds.length, 'first:', containerIds[0]);

    const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
    const running = [];
    const stopped = [];
    const warmStatusMap = await getWarmJobsStatus(containerIds);
    const targetNames = new Set(containerIds);
    const dockerStatusByName = new Map();

    // Single Docker call for all containers (much faster than 1 call/container).
    const { stdout: dockerStatuses } = await execAsync(
      'docker ps -a --format "{{.Names}}|{{.Status}}"',
      { cwd: projectDir, shell: '/bin/sh', timeout: 5000 }
    );
    for (const rawLine of (dockerStatuses || '').split('\n')) {
      const line = rawLine.trim();
      if (!line) continue;
      const sep = line.indexOf('|');
      if (sep <= 0) continue;
      const name = line.slice(0, sep).trim();
      if (!targetNames.has(name)) continue;
      const status = line.slice(sep + 1).trim();
      dockerStatusByName.set(name, status);
    }

    for (const name of containerIds) {
      if (warmStatusMap[name]?.running) {
        running.push(name);
        continue;
      }

      const status = (dockerStatusByName.get(name) || '').trim();
      const normalized = status.toLowerCase();
      const isRunning =
        normalized.startsWith('up') ||
        normalized.includes('restarting') ||
        normalized.includes('paused');

      // Treat "Created", "Exited", "Dead", empty status as stopped so stale
      // containers do not keep meeting status active forever.
      if (isRunning) {
        running.push(name);
      } else {
        stopped.push(name);
      }
    }

    console.log('[STATUS] Result: running=', running.length, 'stopped=', stopped.length, 'allStopped=', running.length === 0);
    res.json({ running, stopped, allStopped: running.length === 0 });
  } catch (error) {
    console.error('[STATUS] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/bots/stop - Stop bots
 */
app.post('/api/bots/stop', async (req, res) => {
  try {
    let { containerIds } = req.body;
    console.log('[STOP] Request received. containerCount:', Array.isArray(containerIds) ? containerIds.length : 0, 'first:', Array.isArray(containerIds) ? containerIds[0] : 'N/A');
    
    if (!containerIds) {
      return res.status(400).json({ error: 'containerIds required' });
    }
    
    // Convert string to array if needed
    if (typeof containerIds === 'string') {
      containerIds = containerIds.split(/[,\n]/).map(id => id.trim()).filter(id => id);
    }
    
    if (!Array.isArray(containerIds) || containerIds.length === 0) {
      return res.status(400).json({ error: 'containerIds must be a non-empty array' });
    }
    
    // Clean and validate container IDs
    containerIds = containerIds.map(id => {
      if (typeof id === 'string') {
        return id.trim();
      }
      return String(id).trim();
    }).filter(id => id && id.length > 0);
    
    if (containerIds.length === 0) {
      return res.status(400).json({ error: 'No valid container IDs provided' });
    }
    
    const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
    
    // Stop containers - use parallel batching for better performance
    const results = [];
    const batchSize = 10; // Stop 10 containers at a time in parallel
    
    // Clean container IDs - use as-is if they're already container names
    // Format: zoom-bot-{meetingId}-{requestId}-{botNumber}
    const cleanIds = containerIds
      .filter(id => id && id.length > 0)
      .map(id => {
        const idStr = String(id).trim();
        // If it's already a container name (starts with zoom-bot-), use as-is
        if (idStr.startsWith('zoom-bot-')) {
          return idStr;
        }
        // If it's a container ID (hex string), try to find container by ID
        // Otherwise, escape special characters
        return idStr.replace(/[^a-zA-Z0-9_-]/g, '');
      })
      .filter(id => id && id.length > 0);
    
    console.log('[STOP] projectDir:', projectDir, 'cleanIds count:', cleanIds.length);
    
    // Process in batches
    for (let i = 0; i < cleanIds.length; i += batchSize) {
      const batch = cleanIds.slice(i, i + batchSize);

      // First stop jobs running on warm workers (virtual bot IDs share zoom-bot-* naming).
      const warmResults = await stopWarmJobs(batch);
      const warmHandled = new Set();
      for (const wr of warmResults) {
        if (wr.status !== 'not_warm') {
          warmHandled.add(wr.id);
          results.push({
            id: wr.id,
            status: wr.status === 'stopped' ? 'stopped' : 'already_stopped'
          });
        }
      }

      const dockerBatch = batch.filter((id) => !warmHandled.has(id));
      if (!dockerBatch.length) {
        continue;
      }
      
      // Stop batch in parallel
      const batchPromises = dockerBatch.map(async (containerId) => {
        try {
          // First check if container exists and is running
          try {
            const { stdout } = await execAsync(`docker ps -a --filter "name=^${containerId}$" --format "{{.Status}}"`, {
              cwd: projectDir,
              shell: '/bin/sh',
              timeout: 2000
            });
            
            // If container doesn't exist or already stopped - remove (docker rm -f works on exited)
            if (!stdout || stdout.trim() === '' || stdout.includes('Exited')) {
              try {
                await execAsync(`docker rm -f ${containerId}`, { cwd: projectDir, shell: '/bin/sh', timeout: 5000 });
                console.log(`✅ Removed exited container: ${containerId}`);
              } catch (rmErr) {
                if (!rmErr.message.includes('No such container')) console.warn(`⚠️ docker rm ${containerId}:`, rmErr.message);
              }
              return { id: containerId, status: 'already_stopped' };
            }
          } catch (checkError) {
            // Container might not exist, try to stop anyway
            console.log(`⚠️  Could not check status of ${containerId}, attempting stop...`);
          }
          
          // Stop and remove container
          await execAsync(`docker stop ${containerId}`, { 
            cwd: projectDir, 
            shell: '/bin/sh',
            timeout: 5000
          });
          try {
            await execAsync(`docker rm ${containerId}`, { cwd: projectDir, shell: '/bin/sh', timeout: 3000 });
            console.log(`✅ Stopped and removed container: ${containerId}`);
          } catch (rmErr) {
            console.log(`✅ Stopped container: ${containerId} (rm: ${rmErr.message})`);
          }
          return { id: containerId, status: 'stopped' };
        } catch (error) {
          // If error says container doesn't exist or already stopped, that's OK
          if (error.message.includes('No such container') || 
              error.message.includes('already stopped') ||
              error.message.includes('is not running')) {
            console.log(`ℹ️  Container ${containerId} already stopped or doesn't exist`);
            return { id: containerId, status: 'already_stopped' };
          }
          console.error(`❌ Error stopping container ${containerId}:`, error.message);
          return { id: containerId, status: 'failed', error: error.message };
        }
      });
      
      // Wait for batch to complete
      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults);
      
      // Small delay between batches to avoid overwhelming Docker
      if (i + batchSize < cleanIds.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    // Remove compose file: zoom-bot-{meetingId}-{requestId}-{n} -> compose-{meetingId}-{requestId}-bots.yaml
    const firstId = cleanIds[0] || '';
    const match = firstId.match(/^zoom-bot-(\d+)-(\d+)-\d+$/);
    console.log('[STOP] Parse firstId:', firstId, 'match:', !!match, 'expected compose: compose-' + (match ? `${match[1]}-${match[2]}-bots.yaml` : '?'));
    if (match) {
      const [, meetingId, requestId] = match;
      const composeFile = path.join(projectDir, `compose-${meetingId}-${requestId}-bots.yaml`);
      const exists = fs.existsSync(composeFile);
      console.log('[STOP] Compose file:', composeFile, 'exists:', exists);
      if (fs.existsSync(composeFile)) {
        try {
          fs.unlinkSync(composeFile);
          console.log(`✅ Deleted compose file: compose-${meetingId}-${requestId}-bots.yaml`);
        } catch (e) {
          console.warn(`⚠️  Could not delete compose file: ${e.message}`);
        }
      } else {
        console.warn(`⚠️  Compose file not found: ${composeFile}`);
      }
    } else {
      console.warn(`⚠️  Could not parse meeting/request from container name: ${firstId}`);
    }

    const successCount = results.filter(r => r.status === 'stopped' || r.status === 'already_stopped').length;
    const failCount = results.filter(r => r.status === 'failed').length;
    const alreadyStoppedCount = results.filter(r => r.status === 'already_stopped').length;
    
    console.log('[STOP] Done. successCount:', successCount, 'failCount:', failCount);
    res.json({
      success: true,
      message: `Stopped ${successCount} of ${containerIds.length} containers (${alreadyStoppedCount} were already stopped)`,
      results: results,
      successCount,
      failCount,
      alreadyStoppedCount
    });
  } catch (error) {
    console.error('Error stopping bots:', error);
    res.status(500).json({ 
      error: 'Failed to stop bots',
      message: error.message 
    });
  }
});

/**
 * POST /api/bots/cleanup-compose - Remove containers and delete compose file by meetingId+requestId
 * Use when stop didn't run (e.g. API unreachable). No auth - for internal/cron use.
 */
app.post('/api/bots/cleanup-compose', async (req, res) => {
  try {
    const { meetingId, requestId } = req.body;
    console.log('[CLEANUP-COMPOSE] Request:', { meetingId, requestId });
    if (!meetingId || !requestId) {
      return res.status(400).json({ error: 'meetingId and requestId required' });
    }
    const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
    const prefix = `zoom-bot-${meetingId}-${requestId}`;
    const composeFile = path.join(projectDir, `compose-${meetingId}-${requestId}-bots.yaml`);
    const warmPrefix = `${prefix}-`;

    try {
      const warm = await getWarmPoolStatus();
      if (warm.enabled && Array.isArray(warm.workers)) {
        const warmJobIds = warm.workers
          .filter((worker) => worker.status === 'busy' && worker.jobId && worker.jobId.startsWith(warmPrefix))
          .map((worker) => worker.jobId);
        if (warmJobIds.length) {
          await stopWarmJobs(warmJobIds);
          console.log(`[CLEANUP-COMPOSE] Released ${warmJobIds.length} warm jobs`);
        }
      }
    } catch (e) {
      console.warn(`[CLEANUP-COMPOSE] Warm cleanup skipped: ${e.message}`);
    }

    const { stdout: namesOut } = await execAsync(
      `docker ps -a --filter "name=^${prefix}-" --format "{{.Names}}"`,
      { cwd: projectDir, shell: '/bin/sh', timeout: 5000 }
    );
    const containerNames = (namesOut || '').trim().split('\n').filter(Boolean);
    let removed = 0;
    for (const name of containerNames) {
      try {
        await execAsync(`docker rm -f ${name}`, { cwd: projectDir, shell: '/bin/sh', timeout: 5000 });
        removed++;
        console.log(`✅ Removed container: ${name}`);
      } catch (e) {
        console.warn(`⚠️ Could not remove ${name}:`, e.message);
      }
    }
    let composeDeleted = false;
    if (fs.existsSync(composeFile)) {
      try {
        fs.unlinkSync(composeFile);
        composeDeleted = true;
        console.log(`✅ Deleted compose: compose-${meetingId}-${requestId}-bots.yaml`);
      } catch (e) {
        console.warn(`⚠️ Could not delete compose:`, e.message);
      }
    }
    console.log('[CLEANUP-COMPOSE] Done. removed:', removed, 'composeDeleted:', composeDeleted);
    res.json({ success: true, removed, composeDeleted, containers: containerNames });
  } catch (error) {
    console.error('[CLEANUP-COMPOSE] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/bots/cleanup-by-meeting - Find and clean ALL compose files + containers for a meetingId
 * Use when container_ids missing or stop failed. Finds compose-{meetingId}-*-bots.yaml
 */
app.post('/api/bots/cleanup-by-meeting', async (req, res) => {
  try {
    const { meetingId } = req.body;
    console.log('[CLEANUP-BY-MEETING] Request meetingId:', meetingId);
    if (!meetingId) {
      return res.status(400).json({ error: 'meetingId required' });
    }
    const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
    const warmMeetingPrefix = `zoom-bot-${meetingId}-`;
    try {
      const warm = await getWarmPoolStatus();
      if (warm.enabled && Array.isArray(warm.workers)) {
        const warmJobIds = warm.workers
          .filter((worker) => worker.status === 'busy' && worker.jobId && worker.jobId.startsWith(warmMeetingPrefix))
          .map((worker) => worker.jobId);
        if (warmJobIds.length) {
          await stopWarmJobs(warmJobIds);
          console.log(`[CLEANUP-BY-MEETING] Released ${warmJobIds.length} warm jobs`);
        }
      }
    } catch (e) {
      console.warn(`[CLEANUP-BY-MEETING] Warm cleanup skipped: ${e.message}`);
    }

    const files = fs.readdirSync(projectDir).filter(f => f.startsWith(`compose-${meetingId}-`) && f.endsWith('-bots.yaml'));
    let totalRemoved = 0;
    const cleaned = [];
    for (const file of files) {
      const m = file.match(/^compose-(\d+)-(\d+)-bots\.yaml$/);
      if (m) {
        const [, mid, rid] = m;
        const prefix = `zoom-bot-${mid}-${rid}`;
        const { stdout: namesOut } = await execAsync(
          `docker ps -a --filter "name=^${prefix}-" --format "{{.Names}}"`,
          { cwd: projectDir, shell: '/bin/sh', timeout: 5000 }
        ).catch(() => ({ stdout: '' }));
        const names = (namesOut || '').trim().split('\n').filter(Boolean);
        for (const name of names) {
          try {
            await execAsync(`docker rm -f ${name}`, { cwd: projectDir, shell: '/bin/sh', timeout: 5000 });
            totalRemoved++;
          } catch (_) {}
        }
        try {
          fs.unlinkSync(path.join(projectDir, file));
          cleaned.push(file);
        } catch (_) {}
      }
    }
    console.log('[CLEANUP-BY-MEETING] Done. totalRemoved:', totalRemoved, 'cleaned:', cleaned);
    res.json({ success: true, totalRemoved, cleaned });
  } catch (error) {
    console.error('[CLEANUP-BY-MEETING] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/bots/status - Get status of running bots
 */
app.get('/api/bots/status', async (req, res) => {
  try {
    const projectDir = path.join(__dirname, '..');
    
    // Get running containers
    const { stdout } = await execAsync(
      'docker ps --filter "name=zoom-bot" --format "{{.ID}} {{.Names}} {{.Status}}"',
      { cwd: projectDir, shell: '/bin/sh' }
    );
    
    const bots = stdout.trim().split('\n').filter(line => line).map(line => {
      const [id, name, ...statusParts] = line.split(' ');
      return {
        containerId: id,
        name,
        status: statusParts.join(' ')
      };
    });

    try {
      const warm = await getWarmPoolStatus();
      if (warm.enabled && Array.isArray(warm.workers)) {
        for (const worker of warm.workers) {
          if (worker.status === 'busy' && worker.jobId) {
            bots.push({
              containerId: worker.name,
              name: worker.jobId,
              status: `Up (warm-worker:${worker.name})`
            });
          }
        }
      }
    } catch {
      // ignore warm pool status errors in status endpoint
    }
    
    res.json({
      success: true,
      bots,
      count: bots.length
    });
  } catch (error) {
    console.error('Error getting bot status:', error);
    res.status(500).json({ 
      error: 'Failed to get bot status',
      message: error.message 
    });
  }
});

/**
 * GET /api/bots/capacity - Get server capacity info
 */
app.get('/api/bots/capacity', async (req, res) => {
  try {
    const projectDir = path.join(__dirname, '..');
    
    // Get running containers count
    const { stdout: runningCount } = await execAsync(
      'docker ps --filter "name=zoom-bot" -q | wc -l',
      { cwd: projectDir, shell: '/bin/sh' }
    );
    
    const composeLoad = parseInt(runningCount.trim(), 10) || 0;
    let warmBusy = 0;
    try {
      const warm = await getWarmPoolStatus();
      warmBusy = warm.enabled ? Number.parseInt(warm.busyCount, 10) || 0 : 0;
    } catch {
      warmBusy = 0;
    }
    const currentLoad = composeLoad + warmBusy;
    const capacity = parseInt(process.env.SERVER_CAPACITY || 100, 10);
    const cpuUsagePercent = await getCpuUsagePercent(250);
    const cpuCores = os.cpus()?.length || 0;
    const cpuTargetPercent = Math.max(50, Math.min(95, toNumber(process.env.CAPACITY_TARGET_CPU_PERCENT, 85)));

    let cpuBasedCapacity = null;
    if (Number.isFinite(cpuUsagePercent)) {
      if (currentLoad > 0) {
        const avgCpuPerBotPercent = cpuUsagePercent / currentLoad;
        if (avgCpuPerBotPercent > 0) {
          cpuBasedCapacity = Math.floor(cpuTargetPercent / avgCpuPerBotPercent);
        }
      } else {
        const perBotCpuCores =
          toNumber(process.env.CAPACITY_CPU_PER_BOT, null) ??
          toNumber(process.env.AUDIO_CPU_LIMIT, null) ??
          toNumber(process.env.VIDEO_CPU_LIMIT, 0.1);
        if (cpuCores > 0 && perBotCpuCores > 0) {
          cpuBasedCapacity = Math.floor((cpuCores * (cpuTargetPercent / 100)) / perBotCpuCores);
        }
      }
    }

    let effectiveCapacity = capacity;
    if (Number.isFinite(cpuBasedCapacity) && cpuBasedCapacity > 0) {
      effectiveCapacity = Math.min(capacity, Math.max(currentLoad, cpuBasedCapacity));
    }

    const available = Math.max(0, effectiveCapacity - currentLoad);
    const schedulerLoad = Math.min(capacity, currentLoad + Math.max(0, capacity - effectiveCapacity));
    
    res.json({
      success: true,
      capacity,
      currentLoad,
      schedulerLoad,
      effectiveCapacity,
      available,
      composeLoad,
      warmBusy,
      cpuUsagePercent,
      cpuTargetPercent,
      cpuCores
    });
  } catch (error) {
    console.error('Error getting capacity:', error);
    res.status(500).json({ 
      error: 'Failed to get capacity',
      message: error.message 
    });
  }
});

/**
 * GET /api/bots/pool/status - Show warm pool status
 */
app.get('/api/bots/pool/status', async (req, res) => {
  try {
    const status = await getWarmPoolStatus();
    res.json({ success: true, ...status });
  } catch (error) {
    console.error('Error getting warm pool status:', error);
    res.status(500).json({
      error: 'Failed to get warm pool status',
      message: error.message
    });
  }
});

/**
 * POST /api/bots/pool/refill - Ensure warm pool target is met
 */
app.post('/api/bots/pool/refill', async (req, res) => {
  try {
    const status = await ensureWarmPool();
    res.json({ success: true, ...status });
  } catch (error) {
    console.error('Error refilling warm pool:', error);
    res.status(500).json({
      error: 'Failed to refill warm pool',
      message: error.message
    });
  }
});

// Manual ZAK refresh trigger (POST or GET)
const doRefreshZak = async (req, res) => {
  try {
    const { refreshZak } = require('./zakRefresh');
    const ok = await refreshZak();
    res.json({ success: ok });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
};
app.post('/api/bots/refresh-zak', doRefreshZak);
app.get('/api/bots/refresh-zak', doRefreshZak);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`🤖 Bot Server API running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  ensureWarmPool()
    .then((status) => {
      if (status.enabled) {
        console.log(`🔥 Warm pool initialized: ${status.running}/${status.targetSize}`);
      }
    })
    .catch((error) => {
      console.log(`[WARM-POOL] Init skipped: ${error.message}`);
    });
  // ZAK pre-generate job: every 2 hours, saves to zak-token.env
  try {
    const { startZakRefreshJob } = require('./zakRefresh');
    startZakRefreshJob();
  } catch (e) {
    console.log('[ZAK] Refresh job not started:', e.message);
  }
});
