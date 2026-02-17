const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const { exec } = require('child_process');

const execAsync = promisify(exec);

function asInt(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function shellQuote(value) {
  const str = value == null ? '' : String(value);
  return `'${str.replace(/'/g, `'\"'\"'`)}'`;
}

function isEnabledFlag(value) {
  return ['1', 'true', 'yes', 'y', 'on'].includes(String(value || '').toLowerCase());
}

function getProjectDir() {
  return process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
}

function getStatePath() {
  return path.join(getProjectDir(), '.warm-pool-state.json');
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
  const prebuiltRuntime = isEnabledFlag(process.env.BOT_PREBUILT_RUNTIME);
  const directAssign = isEnabledFlag(process.env.BOT_WARM_POOL_DIRECT_ASSIGN ?? 'true');
  const prefix = (process.env.BOT_WARM_POOL_PREFIX || 'zoom-warm-bot').trim();

  return {
    prebuiltRuntime,
    directAssign,
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

function createEmptyState() {
  return { version: 1, workers: {} };
}

function readState() {
  const statePath = getStatePath();
  if (!fs.existsSync(statePath)) return createEmptyState();

  try {
    const parsed = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    if (!parsed || typeof parsed !== 'object' || typeof parsed.workers !== 'object') {
      return createEmptyState();
    }
    return {
      version: 1,
      workers: parsed.workers
    };
  } catch {
    return createEmptyState();
  }
}

function writeState(state) {
  const statePath = getStatePath();
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2), 'utf8');
}

function normalizeWorkerState(workerState = {}) {
  const status = workerState.status === 'busy' ? 'busy' : 'idle';
  if (status === 'busy') {
    return {
      status: 'busy',
      jobId: workerState.jobId || '',
      meetingId: workerState.meetingId || '',
      requestId: workerState.requestId || '',
      assignedAt: workerState.assignedAt || new Date().toISOString()
    };
  }
  return { status: 'idle' };
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

async function isWorkerRunningBotProcess(workerName) {
  try {
    const { stdout } = await execAsync(
      `docker exec ${shellQuote(workerName)} sh -lc ${shellQuote("pgrep -f '/opt/zoomsdk-runtime/zoomsdk' >/dev/null 2>&1 && echo running || echo idle")}`,
      getDockerExecOptions()
    );
    return (stdout || '').trim() === 'running';
  } catch {
    return false;
  }
}

function attachContainersToState(containers, state) {
  const nextWorkers = {};
  for (const container of containers) {
    const existing = state.workers[container.name];
    nextWorkers[container.name] = normalizeWorkerState(existing);
  }
  state.workers = nextWorkers;
}

async function refreshBusyWorkers(state, containersByName) {
  for (const [workerName, workerState] of Object.entries(state.workers)) {
    const container = containersByName.get(workerName);
    if (!container || container.state !== 'running') {
      state.workers[workerName] = { status: 'idle' };
      continue;
    }

    const processRunning = await isWorkerRunningBotProcess(workerName);
    if (workerState.status === 'busy' && !processRunning) {
      state.workers[workerName] = { status: 'idle' };
      continue;
    }

    if (workerState.status !== 'busy' && processRunning) {
      // Preserve safety if state file was lost: do not reuse this worker until process exits.
      state.workers[workerName] = {
        status: 'busy',
        jobId: workerState.jobId || `orphan-${workerName}`,
        meetingId: workerState.meetingId || '',
        requestId: workerState.requestId || '',
        assignedAt: workerState.assignedAt || new Date().toISOString()
      };
    }
  }
}

function buildWarmStatus(config, containers, state) {
  const workers = containers.map((container) => {
    const workerState = normalizeWorkerState(state.workers[container.name]);
    return {
      name: container.name,
      containerState: container.state,
      status: workerState.status,
      jobId: workerState.jobId || null,
      meetingId: workerState.meetingId || null,
      requestId: workerState.requestId || null,
      assignedAt: workerState.assignedAt || null
    };
  });

  const running = containers.filter((entry) => entry.state === 'running').length;
  const busyCount = workers.filter((entry) => entry.status === 'busy').length;
  const idleCount = workers.filter((entry) => entry.status === 'idle').length;

  return {
    enabled: true,
    directAssignEnabled: config.directAssign,
    targetSize: config.targetSize,
    running,
    total: containers.length,
    busyCount,
    idleCount,
    workers
  };
}

async function ensureWarmPool() {
  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) {
    return {
      enabled: false,
      directAssignEnabled: false,
      targetSize: 0,
      running: 0,
      total: 0,
      busyCount: 0,
      idleCount: 0,
      workers: []
    };
  }

  let containers = await listWarmContainers(config);
  const byName = new Map(containers.map((entry) => [entry.name, entry]));

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

  for (const entry of containers) {
    if ((entry.index || 0) > config.targetSize) {
      await removeWarmContainer(entry.name);
    }
  }

  containers = await listWarmContainers(config);
  const containersByName = new Map(containers.map((entry) => [entry.name, entry]));
  const state = readState();
  attachContainersToState(containers, state);
  await refreshBusyWorkers(state, containersByName);
  writeState(state);

  return buildWarmStatus(config, containers, state);
}

async function getWarmPoolStatus() {
  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) {
    return {
      enabled: false,
      directAssignEnabled: false,
      targetSize: 0,
      running: 0,
      total: 0,
      busyCount: 0,
      idleCount: 0,
      workers: []
    };
  }

  const containers = await listWarmContainers(config);
  const containersByName = new Map(containers.map((entry) => [entry.name, entry]));
  const state = readState();
  attachContainersToState(containers, state);
  await refreshBusyWorkers(state, containersByName);
  writeState(state);
  return buildWarmStatus(config, containers, state);
}

async function killWorkerProcess(workerName) {
  const killCmd = [
    'pkill -TERM -f "/opt/zoomsdk-runtime/zoomsdk" >/dev/null 2>&1 || true',
    'pkill -TERM -f "timeout .*zoomsdk" >/dev/null 2>&1 || true',
    'sleep 0.2',
    'pkill -KILL -f "/opt/zoomsdk-runtime/zoomsdk" >/dev/null 2>&1 || true',
    'pkill -KILL -f "timeout .*zoomsdk" >/dev/null 2>&1 || true'
  ].join('; ');

  try {
    await execAsync(
      `docker exec ${shellQuote(workerName)} sh -lc ${shellQuote(killCmd)}`,
      getDockerExecOptions()
    );
  } catch {
    // no-op
  }
}

function jobToExecCommand(workerName, jobSpec) {
  const envFlags = Object.entries(jobSpec.environment || {})
    .map(([key, value]) => `-e ${shellQuote(`${key}=${value == null ? '' : String(value)}`)}`)
    .join(' ');
  const args = (jobSpec.command || []).map((arg) => shellQuote(String(arg))).join(' ');
  const workingDir = jobSpec.workingDir || '/tmp/meeting-sdk-linux-sample';
  const entryScript = '/opt/zoomsdk-runtime/entry-bot-runtime.sh';

  return `docker exec -d -w ${shellQuote(workingDir)} ${envFlags} ${shellQuote(workerName)} ${shellQuote(entryScript)} ${args}`.trim();
}

async function assignWarmJobs(jobSpecs) {
  const config = getConfig();
  const warmStatus = await ensureWarmPool();
  if (!warmStatus.enabled || !config.directAssign || !Array.isArray(jobSpecs) || jobSpecs.length === 0) {
    return { assigned: [], unassigned: Array.isArray(jobSpecs) ? [...jobSpecs] : [] };
  }

  const state = readState();
  const containers = await listWarmContainers(config);
  const containersByName = new Map(containers.map((entry) => [entry.name, entry]));
  attachContainersToState(containers, state);
  await refreshBusyWorkers(state, containersByName);

  const idleWorkers = containers
    .filter((entry) => entry.state === 'running')
    .map((entry) => entry.name)
    .filter((name) => state.workers[name]?.status === 'idle');

  const assigned = [];
  const unassigned = [];

  for (const spec of jobSpecs) {
    const workerName = idleWorkers.shift();
    if (!workerName) {
      unassigned.push(spec);
      continue;
    }

    try {
      await killWorkerProcess(workerName);
      const command = jobToExecCommand(workerName, spec);
      await execAsync(command, getDockerExecOptions());
      state.workers[workerName] = {
        status: 'busy',
        jobId: spec.jobId,
        meetingId: spec.meetingId || '',
        requestId: spec.requestId || '',
        assignedAt: new Date().toISOString()
      };
      assigned.push({
        jobId: spec.jobId,
        workerName
      });
    } catch (error) {
      state.workers[workerName] = { status: 'idle' };
      unassigned.push(spec);
      console.warn(`[WARM-POOL] Failed to assign ${spec.jobId} to ${workerName}: ${error.message}`);
    }
  }

  writeState(state);
  return { assigned, unassigned };
}

function findWorkerByJobId(state, jobId) {
  for (const [workerName, workerState] of Object.entries(state.workers)) {
    if (workerState.status === 'busy' && workerState.jobId === jobId) {
      return { workerName, workerState };
    }
  }
  return null;
}

async function stopWarmJobs(jobIds) {
  if (!Array.isArray(jobIds) || jobIds.length === 0) return [];

  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) {
    return jobIds.map((jobId) => ({ id: jobId, status: 'not_warm' }));
  }

  const state = readState();
  const containers = await listWarmContainers(config);
  const containersByName = new Map(containers.map((entry) => [entry.name, entry]));
  attachContainersToState(containers, state);
  await refreshBusyWorkers(state, containersByName);

  const results = [];
  for (const jobId of jobIds) {
    const found = findWorkerByJobId(state, jobId);
    if (!found) {
      results.push({ id: jobId, status: 'not_warm' });
      continue;
    }

    await killWorkerProcess(found.workerName);
    state.workers[found.workerName] = { status: 'idle' };
    results.push({ id: jobId, status: 'stopped', worker: found.workerName });
  }

  writeState(state);
  return results;
}

async function getWarmJobsStatus(jobIds) {
  if (!Array.isArray(jobIds) || jobIds.length === 0) return {};

  const config = getConfig();
  if (!config.prebuiltRuntime || config.targetSize <= 0) return {};

  const state = readState();
  const containers = await listWarmContainers(config);
  const containersByName = new Map(containers.map((entry) => [entry.name, entry]));
  attachContainersToState(containers, state);
  await refreshBusyWorkers(state, containersByName);
  writeState(state);

  const statusMap = {};
  for (const jobId of jobIds) {
    const found = findWorkerByJobId(state, jobId);
    if (!found) continue;
    statusMap[jobId] = {
      running: true,
      worker: found.workerName
    };
  }

  return statusMap;
}

module.exports = {
  ensureWarmPool,
  getWarmPoolStatus,
  assignWarmJobs,
  stopWarmJobs,
  getWarmJobsStatus
};
