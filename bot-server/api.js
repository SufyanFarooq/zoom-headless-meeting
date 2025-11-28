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
    // Pass meetingId for unique container names and compose file names
    const hostPath = process.env.HOST_PROJECT_PATH || '/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample';
    // Quote projectDir to handle paths with spaces
    const command = `cd "${projectDir}" && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && HOST_PROJECT_PATH="${hostPath}" MEETING_TYPE="${meetingType}" NAME_TYPE="${nameType}" MEETING_ID="${meetingId}" bash setup-flexible-bots.sh ${video} ${audio} '${joinUrl}' ${accountId} ${clientId} ${clientSecret}`;
    
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
      const composeFilePath = path.join(projectDir, `compose-${meetingId}-bots.yaml`);
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
    // Use meeting ID based compose file name
    const composeFileName = `compose-${meetingId}-bots.yaml`;
    console.log(`📋 Expected compose file: ${composeFileName}`);
    console.log(`📋 Meeting ID used: ${meetingId}`);
    console.log(`📋 Meeting ID type: ${typeof meetingId}`);
    console.log(`📋 Meeting ID value: "${meetingId}"`);
    
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
    
    // Generate container names based on meeting ID and bot numbers
    // This ensures unique names per meeting, avoiding conflicts
    for (let i = 1; i <= totalBots; i++) {
      containerIds.push(`zoom-bot-${meetingId}-${i}`);
    }
    
    // Start containers
    // Use docker-compose (standalone) instead of docker compose (plugin)
    // IMPORTANT: Run from container path, but docker-compose will use host Docker daemon
    // The volume mount ensures files are accessible
    console.log(`🚀 Starting containers...`);
    
    // IMPORTANT: Use container path for docker-compose
    // The compose file is in the container at /app/bot-project/compose-{meetingId}-bots.yaml
    // docker-compose will use the host Docker daemon via socket
    // Force recreate to ensure containers use latest compose file with ZAK tokens
    // Note: --force-recreate will only recreate containers defined in this compose file
    // Other meetings' containers will remain untouched
    const startCommand = `docker-compose -f ${composeFileName} up -d --force-recreate`;
    
    console.log(`📋 Using compose file: "${projectDir}/${composeFileName}"`);
    console.log(`📋 Full compose file path: ${composeFilePath}`);
    console.log(`📋 Command to execute: ${startCommand}`);
    console.log(`📋 Meeting ID: ${meetingId} - Containers: zoom-bot-${meetingId}-1 to zoom-bot-${meetingId}-${totalBots}`);
    console.log(`📋 Force recreating containers to ensure ZAK tokens are used...`);
    
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
      console.error('   Compose file path:', composeFilePath);
      console.error('   Compose file exists:', fs.existsSync(composeFilePath));
      console.error('   Error:', dockerError.message);
      console.error('   Stdout:', dockerError.stdout || '');
      console.error('   Stderr:', dockerError.stderr || '');
      
      // Check if compose file exists
      if (!fs.existsSync(composeFilePath)) {
        throw new Error(`Compose file ${composeFileName} does not exist at ${composeFilePath}. Script may have failed to generate it.`);
      }
      
      // Re-throw with better error message
      throw new Error(`Docker-compose failed: ${dockerError.message}. Command: ${startCommand}. Compose file: ${composeFilePath}`);
    }
    
    // Get actual container IDs using meeting ID based names
    for (let i = 1; i <= totalBots; i++) {
      try {
        const { stdout: containerId } = await execAsync(
          `docker ps -q -f name=zoom-bot-${meetingId}-${i}`,
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
    
    // Stop containers - use parallel batching for better performance
    const results = [];
    const batchSize = 10; // Stop 10 containers at a time in parallel
    
    // Clean container IDs first
    const cleanIds = containerIds
      .filter(id => id && id.length > 0)
      .map(id => {
        // Try to extract container name from ID
        const match = String(id).match(/(\d+)/);
        if (match) {
          return `zoom-bot-${match[1]}`;
        } else if (String(id).startsWith('zoom-bot-')) {
          return String(id).trim();
        } else {
          // Escape special characters for direct ID
          return String(id).replace(/[^a-zA-Z0-9_-]/g, '');
        }
      })
      .filter(id => id && id.length > 0);
    
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
            
            // If container doesn't exist or already stopped
            if (!stdout || stdout.trim() === '' || stdout.includes('Exited')) {
              console.log(`ℹ️  Container ${containerId} already stopped or doesn't exist`);
              return { id: containerId, status: 'already_stopped' };
            }
          } catch (checkError) {
            // Container might not exist, try to stop anyway
            console.log(`⚠️  Could not check status of ${containerId}, attempting stop...`);
          }
          
          // Try to stop the container
          await execAsync(`docker stop ${containerId}`, { 
            cwd: projectDir, 
            shell: '/bin/sh',
            timeout: 5000 // 5 second timeout per container
          });
          console.log(`✅ Stopped container: ${containerId}`);
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
    
    const successCount = results.filter(r => r.status === 'stopped' || r.status === 'already_stopped').length;
    const failCount = results.filter(r => r.status === 'failed').length;
    const alreadyStoppedCount = results.filter(r => r.status === 'already_stopped').length;
    
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

