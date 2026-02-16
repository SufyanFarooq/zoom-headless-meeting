const { promisify } = require('util');
const { exec } = require('child_process');
const path = require('path');

const execAsync = promisify(exec);

function asInt(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function shellQuote(value) {
  const str = value == null ? '' : String(value);
  return `'${str.replace(/'/g, `'\"'\"'`)}'`;
}

function getProjectDir() {
  return process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
}

function getDockerExecOptions() {
  return {
    cwd: getProjectDir(),
    env: { ...process.env, DOCKER_HOST: 'unix:///var/run/docker.sock' },
    shell: '/bin/sh'
  };
}

function getConfig() {
  const targetSize = Math.max(0, asInt(process.env.BOT_WARM_POOL_SIZE, 0));
  const prebuiltRuntime = ['1', 'true', 'yes'].includes(String(process.env.BOT_PREBUILT_RUNTIME || '').toLowerCase());
  const prefix = (process.env.BOT_WARM_POOL_PREFIX || 'zoom-warm-bot').trim();
  return {
    prebuiltRuntime,
    targetSize,
    prefix,
    image: process.env.BOT_WARM_POOL_IMAGE || 'zoom-bot:latest',
    hostProjectPath: process.env.HOST_PROJECT_PATH || '/opt/zoom-headless-meeting',
    mountMode: process.env.PROJECT_MOUNT_MODE || 'rw',
    cpuLimit: process.env.BOT_WARM_POOL_CPU || '0.05',
    memLimit: process.env.BOT_WARM_POOL_MEM || '256m',
    memReservation: process.env.BOT_WARM_POOL_MEM_RESERVATION || '128m'
  };
}

function parseWarmLine(line) {
  const [name = '', state = '', status = ''] = line.split('|');
  if (!name) return null;
  const match = name.match(/-(\d+)$/);
  const index = match ? Number.parseInt(match[1], 10) : null;
  return { name, index, state, status };
}

async function listWarmContainers(config = getConfig()) {
  if (!config.prefix) return [];
  const { stdout } = await execAsync(
    `docker ps -a --filter "name=^${config.prefix}-" --format "{{.Names}}|{{.State}}|{{.Status}}"`,
    getDockerExecOptions()
  );
  return (stdout || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map(parseWarmLine)
    .filter(Boolean)
    .sort((a, b) => (a.index ?? 0) - (b.index ?? 0));
}

async function createWarmContainer(config, index) {
  const name = `${config.prefix}-${index}`;
  const command = [
    'docker run -d',
    `--name ${shellQuote(name)}`,
    '--label zoom.bot.warm_pool=true',
    '--restart unless-stopped',
    `--cpus ${shellQuote(config.cpuLimit)}`,
    `--memory ${shellQuote(config.memLimit)}`,
    `--memory-reservation ${shellQuote(config.memReservation)}`,
    `-v ${shellQuote(`${config.hostProjectPath}:/tmp/meeting-sdk-linux-sample:${config.mountMode}`)}`,
    `-e ${shellQuote('QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false')}`,
    `-e ${shellQuote('QT_QPA_PLATFORM=offscreen')}`,
    `-e ${shellQuote('DISPLAY=:99')}`,
    `-e ${shellQuote('G_MESSAGES_DEBUG=')}`,
    shellQuote(config.image),
    '/opt/zoomsdk-runtime/entry-bot-runtime.sh --warmup-only'
  ].join(' ');

  await execAsync(command, getDockerExecOptions());
  return name;
}

async function startWarmContainer(name) {
  await execAsync(`docker start ${shellQuote(name)}`, getDockerExecOptions());
}

async function removeWarmContainer(name) {
  await execAsync(`docker rm -f ${shellQuote(name)}`, getDockerExecOptions());
}

async function ensureWarmPool() {
  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) {
    return { enabled: false, targetSize: 0, running: 0, total: 0, containers: [] };
  }

  let containers = await listWarmContainers(config);
  const byName = new Map(containers.map((entry) => [entry.name, entry]));

  // Ensure required slots exist and are running.
  for (let i = 1; i <= config.targetSize; i++) {
    const name = `${config.prefix}-${i}`;
    const existing = byName.get(name);
    if (!existing) {
      await createWarmContainer(config, i);
      continue;
    }
    if (existing.state !== 'running') {
      await startWarmContainer(name);
    }
  }

  // Remove extra warm containers if pool size was lowered.
  for (const entry of containers) {
    if ((entry.index || 0) > config.targetSize) {
      await removeWarmContainer(entry.name);
    }
  }

  containers = await listWarmContainers(config);
  const running = containers.filter((entry) => entry.state === 'running').length;
  return {
    enabled: true,
    targetSize: config.targetSize,
    running,
    total: containers.length,
    containers
  };
}

async function getWarmPoolStatus() {
  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) {
    return { enabled: false, targetSize: 0, running: 0, total: 0, containers: [] };
  }

  const containers = await listWarmContainers(config);
  const running = containers.filter((entry) => entry.state === 'running').length;
  return {
    enabled: true,
    targetSize: config.targetSize,
    running,
    total: containers.length,
    containers
  };
}

module.exports = {
  ensureWarmPool,
  getWarmPoolStatus
};
