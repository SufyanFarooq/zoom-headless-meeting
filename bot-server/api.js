const express = require('express');
const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');

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
      password, 
      joinUrl, 
      videoCount, 
      audioCount, 
      nameType, 
      meetingType,
      accountId,
      clientId,
      clientSecret,
      timeoutSeconds
    } = req.body;
    
    // Log extracted values
    console.log('📋 Extracted values:', {
      meetingId,
      password: password ? '***' : undefined,
      joinUrl,
      videoCount,
      audioCount,
      nameType,
      meetingType,
      accountId: accountId ? '***' : undefined,
      clientId: clientId ? '***' : undefined,
      clientSecret: clientSecret ? '***' : undefined,
      timeoutSeconds
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
    
    console.log(`Creating bots: ${video} video, ${audio} audio`);
    console.log(`⏳ Estimated time: ${Math.ceil((video + audio) * 2)} seconds (ZAK token generation)`);
    
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
    
    // Build command to run setup-flexible-bots.sh
    // Use bash explicitly and make scripts executable
    // Pass HOST_PROJECT_PATH so generate-flexible-bots.sh can use it in volume mounts
    // Pass meetingType to determine if ZAK tokens should be generated
    // Pass nameType to determine which names file to use (Indian/International)
    const hostPath = process.env.HOST_PROJECT_PATH || '/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample';
    const command = `cd ${projectDir} && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && HOST_PROJECT_PATH="${hostPath}" MEETING_TYPE="${meetingType}" NAME_TYPE="${nameType}" bash setup-flexible-bots.sh ${video} ${audio} '${joinUrl}' ${accountId} ${clientId} ${clientSecret}`;
    
    // Execute setup script
    // Increase timeout for large bot counts (10 bots can take 2-3 minutes)
    // ZAK token generation: ~1-2 seconds per bot (sequential API calls)
    // Compose file generation: ~1-2 seconds
    // Container startup: ~5-10 seconds
    const totalBots = video + audio;
    const scriptTimeout = Math.max(180000, totalBots * 15000); // 15 seconds per bot, minimum 3 minutes
    
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
    
    const { stdout, stderr } = await execAsync(command, {
      cwd: projectDir,
      timeout: scriptTimeout,
      shell: '/bin/sh' // Explicitly specify shell
    });
    
    console.log(`✅ Setup script completed`);
    console.log(`📋 Script output:`);
    console.log(stdout);
    
    if (stderr && !stderr.includes('Warning')) {
      console.error('Setup script stderr:', stderr);
    }
    
    // Get container IDs from compose file
    // Parse compose-50-bots.yaml to get container names
    const containerIds = [];
    // totalBots is already declared above (line 96)
    
    // Generate container names based on bot numbers
    for (let i = 1; i <= totalBots; i++) {
      containerIds.push(`zoom-bot-${i}`);
    }
    
    // Start containers
    // Use docker-compose (standalone) instead of docker compose (plugin)
    // IMPORTANT: Run from container path, but docker-compose will use host Docker daemon
    // The volume mount ensures files are accessible
    console.log(`🚀 Starting containers...`);
    
    // IMPORTANT: Use container path for docker-compose
    // The compose file is in the container at /app/bot-project/compose-50-bots.yaml
    // docker-compose will use the host Docker daemon via socket
    // Force recreate to ensure containers use latest compose file with ZAK tokens
    const startCommand = `docker-compose -f compose-50-bots.yaml up -d --force-recreate`;
    
    console.log(`📋 Using compose file: ${projectDir}/compose-50-bots.yaml`);
    console.log(`📋 Force recreating containers to ensure ZAK tokens are used...`);
    
    await execAsync(startCommand, { 
      cwd: projectDir, // Use container path for docker-compose
      env: {
        ...process.env,
        DOCKER_HOST: 'unix:///var/run/docker.sock'
      },
      shell: '/bin/sh' // Explicitly specify shell
    });
    
    // Get actual container IDs
    for (let i = 1; i <= totalBots; i++) {
      try {
        const { stdout: containerId } = await execAsync(
          `docker ps -q -f name=zoom-bot-${i}`,
          { cwd: projectDir, shell: '/bin/sh' }
        );
        if (containerId.trim()) {
          containerIds.push(containerId.trim());
        }
      } catch (error) {
        // Container might not exist yet
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
 * POST /api/bots/stop - Stop bots
 */
app.post('/api/bots/stop', async (req, res) => {
  try {
    let { containerIds } = req.body;
    
    // Handle both array and string formats
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
    
    const projectDir = path.join(__dirname, '..');
    
    // Stop containers
    // Also try stopping by container name (zoom-bot-N) if ID doesn't work
    const results = [];
    for (const containerId of containerIds) {
      if (!containerId || containerId.length === 0) {
        continue; // Skip empty IDs
      }
      
      try {
        // First try by ID (escape special characters)
        const escapedId = containerId.replace(/[^a-zA-Z0-9_-]/g, '');
        if (escapedId && escapedId.length > 0) {
          await execAsync(`docker stop ${escapedId}`, { cwd: projectDir, shell: '/bin/sh' });
          console.log(`✅ Stopped container: ${escapedId}`);
          results.push({ id: escapedId, status: 'stopped' });
        }
      } catch (error) {
        // If ID fails, try by name (zoom-bot-N format)
        try {
          // Extract number from container ID if it's just a number
          let containerName = containerId;
          if (!containerName.startsWith('zoom-bot-')) {
            // Try to extract number from ID
            const match = containerId.match(/(\d+)/);
            if (match) {
              containerName = `zoom-bot-${match[1]}`;
            } else {
              containerName = `zoom-bot-${containerId}`;
            }
          }
          
          await execAsync(`docker stop ${containerName}`, { cwd: projectDir, shell: '/bin/sh' });
          console.log(`✅ Stopped container by name: ${containerName}`);
          results.push({ id: containerId, name: containerName, status: 'stopped' });
        } catch (nameError) {
          console.error(`❌ Error stopping container ${containerId}:`, nameError.message);
          results.push({ id: containerId, status: 'failed', error: nameError.message });
          // Continue with other containers even if one fails
        }
      }
    }
    
    const successCount = results.filter(r => r.status === 'stopped').length;
    const failCount = results.filter(r => r.status === 'failed').length;
    
    res.json({
      success: true,
      message: `Stopped ${successCount} of ${containerIds.length} containers`,
      results: results,
      successCount,
      failCount
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

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`🤖 Bot Server API running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});

