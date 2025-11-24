const express = require('express');
const router = express.Router();
const { addCustomName } = require('../services/nameService');

/**
 * POST /api/names - Add custom name
 */
router.post('/', async (req, res) => {
  try {
    const { name, nameType } = req.body;
    
    if (!name || !nameType) {
      return res.status(400).json({ 
        error: 'Missing required fields: name, nameType' 
      });
    }
    
    if (!['Indian', 'International'].includes(nameType)) {
      return res.status(400).json({ 
        error: 'nameType must be "Indian" or "International"' 
      });
    }
    
    const success = addCustomName(name, nameType);
    
    if (success) {
      res.json({
        success: true,
        message: `Name "${name}" added to ${nameType} names`
      });
    } else {
      res.status(500).json({ 
        error: 'Failed to add name' 
      });
    }
  } catch (error) {
    console.error('Error adding name:', error);
    res.status(500).json({ 
      error: 'Failed to add name',
      message: error.message 
    });
  }
});

module.exports = router;

