const { query } = require('../db');
const { createBots } = require('../services/botService');
const { updateUsage } = require('../services/usageService');
const cron = require('node-cron');

/**
 * Background scheduler worker
 * Uses cron job to check every minute for due scheduled tasks
 */
class Scheduler {
  constructor() {
    this.cronJob = null;
    this.isRunning = false;
  }
  
  /**
   * Check for due scheduled tasks and execute them
   */
  async checkAndExecuteSchedules() {
    try {
      const nowUTC = new Date();
      console.log(`⏰ Scheduler check at ${nowUTC.toISOString()} UTC`);
      
      // Find all pending tasks that are due
      // scheduled_time_ist is stored as UTC (converted from IST)
      // We compare with NOW() which is also UTC in PostgreSQL
      // Cron runs every minute at :00 seconds
      // Execute if:
      //   - scheduled_time_ist <= NOW() (due or past)
      //   - scheduled_time_ist >= NOW() - INTERVAL '1 hour' (not more than 1 hour old)
      //   - EXTRACT(EPOCH FROM (NOW() - scheduled_time_ist)) >= 0 (scheduled time has passed)
      // This ensures tasks execute ONLY at or after scheduled time, not before
      // We use EXTRACT(EPOCH) to ensure precise time comparison
      const result = await query(
        `SELECT * FROM scheduled_tasks 
         WHERE status = 'pending' 
         AND scheduled_time_ist <= NOW()
         AND scheduled_time_ist >= NOW() - INTERVAL '1 hour'
         AND EXTRACT(EPOCH FROM (NOW() - scheduled_time_ist)) >= 0
         ORDER BY scheduled_time_ist ASC`
      );
      
      if (result.rows.length === 0) {
        console.log('⏰ No due scheduled tasks found');
        return; // No due tasks
      }
      
      console.log(`✅ Found ${result.rows.length} due scheduled task(s)`);
      
      // Execute each due task
      for (const task of result.rows) {
        try {
          console.log(`Executing scheduled task ${task.id} for meeting ${task.meeting_id}`);
          
          // Create bots (same as regular meeting creation)
          // Use video_count and audio_count from scheduled_tasks table
          // If not present or 0 (for old records), calculate 50/50 split as fallback
          const videoCount = (task.video_count !== undefined && task.video_count !== null && task.video_count > 0)
            ? task.video_count 
            : Math.floor(task.members_count / 2);
          const audioCount = (task.audio_count !== undefined && task.audio_count !== null && task.audio_count > 0)
            ? task.audio_count 
            : (task.members_count - videoCount);
          
          // Log parameters before calling createBots
          console.log(`📋 Scheduler calling createBots with:`, {
            meetingId: task.meeting_id,
            password: '***',
            membersCount: task.members_count,
            videoCount,
            audioCount,
            nameType: task.name_type,
            meetingType: task.meeting_type,
            timeoutSeconds: task.timeout_seconds || 7200
          });
          
          const botResult = await createBots(
            task.meeting_id,
            task.password,
            task.members_count,
            videoCount,
            audioCount,
            task.name_type,
            task.meeting_type,
            task.timeout_seconds || 7200
          );
          
          // Create meeting record
          await query(
            `INSERT INTO meetings 
             (meeting_id, password, members_count, name_type, meeting_type, status, 
              timeout_seconds, bot_server_id, container_ids, video_count, audio_count, started_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())`,
            [
              task.meeting_id,
              task.password,
              task.members_count,
              task.name_type,
              task.meeting_type,
              'active',
              task.timeout_seconds || 7200,
              botResult.serverId,
              botResult.containerIds,
              botResult.videoCount,
              botResult.audioCount
            ]
          );
          
          // Update usage
          await updateUsage(task.members_count);
          
          // Mark task as executed
          await query(
            `UPDATE scheduled_tasks 
             SET status = 'executed', executed_at = NOW()
             WHERE id = $1`,
            [task.id]
          );
          
          console.log(`✅ Successfully executed scheduled task ${task.id} for meeting ${task.meeting_id}`);
        } catch (error) {
          console.error(`❌ Error executing scheduled task ${task.id} for meeting ${task.meeting_id}:`, error);
          console.error('Error details:', {
            message: error.message,
            stack: error.stack,
            taskId: task.id,
            meetingId: task.meeting_id
          });
          // Mark as failed but don't stop other tasks
          await query(
            `UPDATE scheduled_tasks 
             SET status = 'failed'
             WHERE id = $1`,
            [task.id]
          );
        }
      }
    } catch (error) {
      console.error('Error in scheduler:', error);
    }
  }
  
  /**
   * Start the scheduler
   * Uses cron job to run every minute
   */
  start() {
    if (this.isRunning) {
      console.log('Scheduler is already running');
      return;
    }
    
    console.log('🕐 Starting scheduler (cron job: every minute at :00 seconds)...');
    this.isRunning = true;
    
    // Don't run immediately on start - wait for first cron execution
    // This prevents executing tasks that were just created
    // Cron will run at the next :00 second
    
    // Run every minute using cron at :00 seconds
    // Cron format: '* * * * *' = every minute at :00 seconds
    this.cronJob = cron.schedule('* * * * *', () => {
      this.checkAndExecuteSchedules();
    }, {
      scheduled: true,
      timezone: 'UTC' // Database stores times in UTC
    });
    
    console.log('⏰ Scheduler will run at the next minute mark (:00 seconds)');
  }
  
  /**
   * Stop the scheduler
   */
  stop() {
    if (this.cronJob) {
      this.cronJob.stop();
      this.cronJob = null;
    }
    this.isRunning = false;
    console.log('Scheduler stopped');
  }
}

// Export singleton instance
const scheduler = new Scheduler();

module.exports = scheduler;

