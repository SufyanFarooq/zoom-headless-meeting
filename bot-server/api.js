const express = require('express');
const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs');

// Load .env for bot-server when running locally (docker-compose already injects env)
require('dotenv').config();

const execAsync = promisify(exec);

const app = express();
const PORT = process.env.BOT_SERVER_PORT || 3001;

app.use(express.json());

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
      videoFile
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
    const zakTimeEst = meetingType === 'Profile Pic Member' 
      ? Math.ceil(totalBotsForLog / 20) + 5  // ~20 parallel, +5s overhead
      : 0;
    console.log(`Creating bots: ${video} video, ${audio} audio`);
    console.log(`⏳ Estimated time: ~${zakTimeEst + Math.ceil(totalBotsForLog / 10) + 15}s (ZAK ${zakTimeEst}s + containers ~${Math.ceil(totalBotsForLog/10)}s)`);
    
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
    console.log(`⏱️  Timeout: ${timeoutSecs}s (from request: ${timeoutSeconds}, bots will leave meeting after this)`);
    // Pass timeout as 9th arg (reliable in Docker/exec); env TIMEOUT_SECONDS may not propagate
    const videoFileEnv = (typeof videoFile === 'string' && videoFile.trim().length > 0) ? videoFile.trim() : '';
    const command = `cd "${projectDir}" && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && VIDEO_FILE="${videoFileEnv}" MEETING_TYPE="${meetingType}" NAME_TYPE="${nameType}" NAME_OFFSET=${nameOffset} USE_SINGLE_ZAK=${useSingleZakEnv} bash setup-flexible-bots.sh ${video} ${audio} '${joinUrl}' ${accountId} ${clientId} ${clientSecret} ${meetingId} ${uniqueRequestId} ${timeoutSecs}`;
    
    // Execute setup script
    // With parallel ZAK: ~20s for 150 bots. Container startup: ~2-3s per 10 containers
    const totalBots = video + audio;
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
      const composeFilePath = path.join(projectDir, `compose-${meetingId}-${uniqueRequestId}-bots.yaml`);
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
    
    // Get container IDs from compose file
    // Use meeting ID + request ID for unique compose file name
    // This ensures each bot creation request gets its own compose file
    const composeFileName = `compose-${meetingId}-${uniqueRequestId}-bots.yaml`;
    console.log(`📋 Expected compose file: ${composeFileName}`);
    console.log(`📋 Meeting ID: ${meetingId}`);
    console.log(`📋 Request ID: ${uniqueRequestId}`);
    console.log(`📋 This ensures unique compose file even for same meeting`);
    
    // Verify compose file exists before trying to use it
    const composeFilePath = path.join(projectDir, composeFileName);
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
    const containerIds = [];
    // totalBots is already declared above (line 96)
    // Note: containerIds will be populated AFTER containers are started (see below)
    
    // Start containers
    // Use docker-compose (standalone) instead of docker compose (plugin)
    // IMPORTANT: Run from container path, but docker-compose will use host Docker daemon
    // The volume mount ensures files are accessible
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
    console.log(`📋 Command to execute: ${startCommand}`);
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
    
    try {
      await execAsync(startCommand, { 
        cwd: projectDir, // Use container path for docker-compose
        env: {
          ...process.env,
          DOCKER_HOST: 'unix:///var/run/docker.sock'
        },
        shell: '/bin/sh' // Explicitly specify shell
      });
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
    
    // Get actual container IDs using meeting ID + request ID based names
    // Format: zoom-bot-{meetingId}-{requestId}-{botNumber}
    for (let i = 1; i <= totalBots; i++) {
      const containerName = `zoom-bot-${meetingId}-${uniqueRequestId}-${i}`;
      try {
        const { stdout: containerId } = await execAsync(
          `docker ps -q -f name=^${containerName}$`,
          { cwd: projectDir, shell: '/bin/sh' }
        );
        if (containerId.trim()) {
          containerIds.push(containerName); // Use container name, not ID
        } else {
          // Fallback: try to get by name directly
          containerIds.push(containerName);
        }
      } catch (error) {
        // Container might not exist yet, but add name anyway
        containerIds.push(containerName);
      }
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

    for (const name of containerIds) {
      try {
        const { stdout } = await execAsync(
          `docker ps -a --filter "name=^${name}$" --format "{{.Status}}"`,
          { cwd: projectDir, shell: '/bin/sh', timeout: 2000 }
        );
        const status = (stdout || '').trim();
        if (status && !status.includes('Exited')) {
          running.push(name);
        } else {
          stopped.push(name);
        }
      } catch {
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
      
      // Stop batch in parallel
      const batchPromises = batch.map(async (containerId) => {
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
    
    const currentLoad = parseInt(runningCount.trim()) || 0;
    const capacity = parseInt(process.env.SERVER_CAPACITY || 100);
    
    res.json({
      success: true,
      capacity,
      currentLoad,
      available: capacity - currentLoad
    });
  } catch (error) {
    console.error('Error getting capacity:', error);
    res.status(500).json({ 
      error: 'Failed to get capacity',
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
  // ZAK pre-generate job: every 2 hours, saves to zak-token.env
  try {
    const { startZakRefreshJob } = require('./zakRefresh');
    startZakRefreshJob();
  } catch (e) {
    console.log('[ZAK] Refresh job not started:', e.message);
  }
});
