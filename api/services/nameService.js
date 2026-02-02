const fs = require('fs');
const path = require('path');

const PROFILE_PICS = path.join(__dirname, '../../profile-pics');
const NAMES_DIR = path.join(PROFILE_PICS, 'names');
const NAMES_INDIAN_FILE = path.join(PROFILE_PICS, 'names.txt');
const NAMES_INTERNATIONAL_FILE = path.join(PROFILE_PICS, 'names-international.txt');

function ensureNamesDir() {
  if (!fs.existsSync(NAMES_DIR)) {
    fs.mkdirSync(NAMES_DIR, { recursive: true });
    if (fs.existsSync(NAMES_INDIAN_FILE)) {
      fs.copyFileSync(NAMES_INDIAN_FILE, path.join(NAMES_DIR, 'Indian.txt'));
    }
    if (fs.existsSync(NAMES_INTERNATIONAL_FILE)) {
      fs.copyFileSync(NAMES_INTERNATIONAL_FILE, path.join(NAMES_DIR, 'International.txt'));
    }
  }
}

function getFilePath(nameType) {
  const safe = String(nameType).replace(/[^a-zA-Z0-9_-]/g, '');
  if (!safe) return null;
  return path.join(NAMES_DIR, `${safe}.txt`);
}

function readNamesFromFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) return [];
    const content = fs.readFileSync(filePath, 'utf8');
    return content
      .split('\n')
      .map(line => line.trim())
      .filter(line => line && !line.startsWith('#'));
  } catch (error) {
    console.error(`Error reading names file ${filePath}:`, error);
    return [];
  }
}

function getNamesForBots(count, nameType) {
  ensureNamesDir();
  let filePath = getFilePath(nameType);
  if (!filePath || !fs.existsSync(filePath)) {
    if (nameType === 'Indian') filePath = NAMES_INDIAN_FILE;
    else if (nameType === 'International') filePath = NAMES_INTERNATIONAL_FILE;
    else filePath = NAMES_INDIAN_FILE;
  }
  const names = readNamesFromFile(filePath);
  const result = [];
  for (let i = 0; i < count; i++) {
    result.push(names.length > 0 ? names[i % names.length] : `Bot-${i + 1}`);
  }
  return result;
}

function addCustomName(name, nameType) {
  ensureNamesDir();
  const filePath = getFilePath(nameType) || (nameType === 'International' ? path.join(NAMES_DIR, 'International.txt') : path.join(NAMES_DIR, 'Indian.txt'));
  try {
    fs.appendFileSync(filePath, `\n${name}`, 'utf8');
    return true;
  } catch (e) {
    console.error('Error adding name:', e);
    return false;
  }
}

function listNameFiles() {
  ensureNamesDir();
  try {
    const files = fs.readdirSync(NAMES_DIR).filter(f => f.endsWith('.txt'));
    return files.map(f => f.replace(/\.txt$/, '')).sort();
  } catch (e) {
    return ['Indian', 'International'];
  }
}

function listNameFilesWithCounts() {
  const names = listNameFiles();
  return names.map(name => {
    const namesList = readNamesFromFile(getFilePath(name));
    return { name, count: namesList.length };
  });
}

function getFileContent(nameType) {
  ensureNamesDir();
  const filePath = getFilePath(nameType);
  if (!filePath || !fs.existsSync(filePath)) return '';
  return fs.readFileSync(filePath, 'utf8');
}

function saveFileContent(nameType, content) {
  ensureNamesDir();
  const filePath = getFilePath(nameType);
  if (!filePath) throw new Error('Invalid name type');
  fs.writeFileSync(filePath, content || '', 'utf8');
  return true;
}

function createNameFile(name) {
  ensureNamesDir();
  const filePath = getFilePath(name);
  if (!filePath) throw new Error('Invalid name');
  if (fs.existsSync(filePath)) throw new Error('File already exists');
  fs.writeFileSync(filePath, '', 'utf8');
  return true;
}

function renameNameFile(oldName, newName) {
  ensureNamesDir();
  const oldPath = getFilePath(oldName);
  const newPath = getFilePath(newName);
  if (!oldPath || !newPath) throw new Error('Invalid name');
  if (!fs.existsSync(oldPath)) throw new Error('File not found');
  if (fs.existsSync(newPath)) throw new Error('Target file already exists');
  fs.renameSync(oldPath, newPath);
  return true;
}

function deleteNameFile(name) {
  ensureNamesDir();
  const filePath = getFilePath(name);
  if (!filePath || !fs.existsSync(filePath)) throw new Error('File not found');
  fs.unlinkSync(filePath);
  return true;
}

module.exports = {
  getNamesForBots,
  addCustomName,
  readNamesFromFile,
  listNameFiles,
  listNameFilesWithCounts,
  getFileContent,
  saveFileContent,
  createNameFile,
  renameNameFile,
  deleteNameFile
};

