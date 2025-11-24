const fs = require('fs');
const path = require('path');

const NAMES_INDIAN_FILE = path.join(__dirname, '../../profile-pics/names.txt');
const NAMES_INTERNATIONAL_FILE = path.join(__dirname, '../../profile-pics/names-international.txt');

/**
 * Read names from file
 */
function readNamesFromFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      console.warn(`Names file not found: ${filePath}`);
      return [];
    }
    
    const content = fs.readFileSync(filePath, 'utf8');
    const names = content
      .split('\n')
      .map(line => line.trim())
      .filter(line => line && !line.startsWith('#'));
    
    return names;
  } catch (error) {
    console.error(`Error reading names file ${filePath}:`, error);
    return [];
  }
}

/**
 * Get names for bots based on name type
 */
function getNamesForBots(count, nameType) {
  let names = [];
  
  if (nameType === 'Indian') {
    names = readNamesFromFile(NAMES_INDIAN_FILE);
  } else if (nameType === 'International') {
    names = readNamesFromFile(NAMES_INTERNATIONAL_FILE);
  } else {
    // Default to Indian if unknown
    names = readNamesFromFile(NAMES_INDIAN_FILE);
  }
  
  // If not enough names, cycle through available names
  const result = [];
  for (let i = 0; i < count; i++) {
    if (names.length > 0) {
      result.push(names[i % names.length]);
    } else {
      // Fallback: generate generic names
      result.push(`Bot-${i + 1}`);
    }
  }
  
  return result;
}

/**
 * Update names file (for adding custom names via dashboard)
 */
function addCustomName(name, nameType) {
  const filePath = nameType === 'Indian' ? NAMES_INDIAN_FILE : NAMES_INTERNATIONAL_FILE;
  
  try {
    // Append name to file
    fs.appendFileSync(filePath, `\n${name}`, 'utf8');
    return true;
  } catch (error) {
    console.error(`Error adding custom name to ${filePath}:`, error);
    return false;
  }
}

module.exports = {
  getNamesForBots,
  addCustomName,
  readNamesFromFile
};

