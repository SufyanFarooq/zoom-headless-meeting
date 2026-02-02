const express = require('express');
const cors = require('cors');
require('dotenv').config();

const meetingsRouter = require('./routes/meetings');
const schedulesRouter = require('./routes/schedules');
const usageRouter = require('./routes/usage');
const namesRouter = require('./routes/names');
const botServersRouter = require('./routes/bot-servers');
const authRouter = require('./routes/auth');
const reportsRouter = require('./routes/reports');
const costSettingsRouter = require('./routes/costSettings');
const adminRouter = require('./routes/admin');
const { authenticate } = require('./middleware/auth');
const { requireAdmin } = require('./middleware/requireAdmin');
const { noCacheSensitiveData } = require('./middleware/cacheControl');
const scheduler = require('./workers/scheduler');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Public Routes
app.use('/api/auth', authRouter);

// Protected Routes (require authentication)
// Apply no-cache middleware BEFORE authenticate to ensure headers are set even for 401 responses
app.use('/api/meetings', noCacheSensitiveData, authenticate, meetingsRouter);
app.use('/api/schedules', noCacheSensitiveData, authenticate, schedulesRouter);
app.use('/api/usage', noCacheSensitiveData, authenticate, usageRouter);
app.use('/api/names', noCacheSensitiveData, authenticate, namesRouter);
app.use('/api/bot-servers', noCacheSensitiveData, authenticate, botServersRouter);
app.use('/api/reports', noCacheSensitiveData, authenticate, reportsRouter);
app.use('/api/cost-settings', noCacheSensitiveData, authenticate, costSettingsRouter);
app.use('/api/admin', noCacheSensitiveData, authenticate, requireAdmin, adminRouter);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: err.message 
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 API Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📝 API endpoints: http://localhost:${PORT}/api`);
  
  // Start scheduler
  scheduler.start();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  scheduler.stop();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  scheduler.stop();
  process.exit(0);
});

module.exports = app;

