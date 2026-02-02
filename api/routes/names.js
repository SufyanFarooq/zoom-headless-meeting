const express = require('express');
const router = express.Router();
const {
  addCustomName,
  listNameFiles,
  listNameFilesWithCounts,
  getFileContent,
  saveFileContent,
  createNameFile,
  renameNameFile,
  deleteNameFile
} = require('../services/nameService');

/** GET /api/names/files - List all name files (withCounts=1 for name count per file) */
router.get('/files', (req, res) => {
  try {
    if (req.query.withCounts === '1') {
      const files = listNameFilesWithCounts();
      res.json({ success: true, files });
    } else {
      const files = listNameFiles();
      res.json({ success: true, files });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/** GET /api/names/files/:name - Get file content */
router.get('/files/:name', (req, res) => {
  try {
    const content = getFileContent(req.params.name);
    res.json({ success: true, content });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/** POST /api/names/files - Create new file */
router.post('/files', (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !/^[a-zA-Z0-9_-]+$/.test(name)) {
      return res.status(400).json({ error: 'Invalid name (letters, numbers, - or _ only)' });
    }
    createNameFile(name);
    res.json({ success: true, message: `File ${name} created` });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

/** PUT /api/names/files/:name - Rename file */
router.put('/files/:name', (req, res) => {
  try {
    const { newName } = req.body;
    if (!newName || !/^[a-zA-Z0-9_-]+$/.test(newName)) {
      return res.status(400).json({ error: 'Invalid newName' });
    }
    renameNameFile(req.params.name, newName);
    res.json({ success: true, message: `Renamed to ${newName}` });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

/** DELETE /api/names/files/:name - Delete file */
router.delete('/files/:name', (req, res) => {
  try {
    deleteNameFile(req.params.name);
    res.json({ success: true, message: 'File deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

/** PUT /api/names/files/:name/content - Save file content */
router.put('/files/:name/content', (req, res) => {
  try {
    const { content } = req.body;
    saveFileContent(req.params.name, typeof content === 'string' ? content : '');
    res.json({ success: true, message: 'Saved' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

/** POST /api/names - Add single name (legacy) */
router.post('/', async (req, res) => {
  try {
    const { name, nameType } = req.body;
    if (!name || !nameType) {
      return res.status(400).json({ error: 'Missing required fields: name, nameType' });
    }
    const success = addCustomName(name, nameType);
    if (success) {
      res.json({ success: true, message: `Name "${name}" added to ${nameType} names` });
    } else {
      res.status(500).json({ error: 'Failed to add name' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
