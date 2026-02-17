const { query } = require('../db');
const { createBots, checkContainersStatus, stopBots } = require('../services/botService');
const { updateUsage, decreaseUsage } = require('../services/usageService');
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
         ORDER BY scheduled_time_ist ASC`
      );
      
      // Log query details for debugging
      if (result.rows.length > 0) {
        console.log(`🔍 Scheduler query found ${result.rows.length} task(s):`, 
          result.rows.map(t => ({
            id: t.id,
            meeting_id: t.meeting_id,
            scheduled_time: t.scheduled_time_ist,
            time_diff_seconds: Math.floor((new Date() - new Date(t.scheduled_time_ist)) / 1000)
          }))
        );
      }
      
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
          // If not present (for old records), calculate 50/50 split as fallback
          // Note: 0 is a valid value, so we only check for undefined/null, not > 0
          const videoCount = (task.video_count !== undefined && task.video_count !== null)
            ? task.video_count 
            : Math.floor(task.members_count / 2);
          const audioCount = (task.audio_count !== undefined && task.audio_count !== null)
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
          
          // Create meeting record (preserve user_id from scheduled task)
          await query(
            `INSERT INTO meetings 
             (meeting_id, password, members_count, name_type, meeting_type, status, 
              timeout_seconds, bot_server_id, container_ids, video_count, audio_count, started_at, user_id)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), $12)`,
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
              botResult.audioCount,
              task.user_id || null
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
          console.log(`📦 Created meeting with containers:`, botResult.containerIds);
        } catch (error) {
          console.error(`❌ Error executing scheduled task ${task.id} for meeting ${task.meeting_id}:`, error);
          console.error('Error details:', {
            message: error.message,
            stack: error.stack,
            taskId: task.id,
            meetingId: task.meeting_id,
            scheduledTime: task.scheduled_time_ist,
            currentTime: new Date().toISOString()
          });
          // Mark as failed but don't stop other tasks
          try {
            await query(
              `UPDATE scheduled_tasks 
               SET status = 'failed', executed_at = NOW()
               WHERE id = $1`,
              [task.id]
            );
            console.log(`⚠️ Task ${task.id} marked as failed`);
          } catch (updateError) {
            console.error(`❌ Failed to update task ${task.id} status:`, updateError);
          }
        }
      }
    } catch (error) {
      console.error('Error in scheduler:', error);
    }

    // Cleanup: mark meetings as stopped when all containers have exited (e.g. timeout)
    try {
      console.log('[CLEANUP] Running checkAndCleanupStoppedMeetings...');
      await this.checkAndCleanupStoppedMeetings();
    } catch (cleanupError) {
      console.error('[CLEANUP] Error:', cleanupError.message);
    }
  }

  /**
   * Check active meetings - if all containers stopped, mark meeting as stopped
   */
  async checkAndCleanupStoppedMeetings() {
    try {
      const result = await query(
        `SELECT id, meeting_id, members_count, container_ids, bot_server_id, timeout_seconds, started_at
         FROM meetings WHERE status = 'active' AND container_ids IS NOT NULL AND array_length(container_ids, 1) > 0`
      );
      if (result.rows.length === 0) return;
      if (result.rows.length > 0) {
        console.log(`[CLEANUP] Found ${result.rows.length} active meeting(s) to check`);
      }

      for (const meeting of result.rows) {
        let containerIds = meeting.container_ids;
        if (!Array.isArray(containerIds)) {
          if (typeof containerIds === 'string') {
            const s = containerIds.replace(/^\{|\}$/g, '').trim();
            containerIds = s ? s.split(/[,\n\r]+/).map(id => id.trim().replace(/^"|"$/g, '')).filter(Boolean) : [];
          } else if (containerIds && typeof containerIds === 'object') {
            containerIds = Object.values(containerIds).map(id => String(id).trim()).filter(Boolean);
          } else {
            containerIds = [];
          }
        }
        if (containerIds.length === 0) {
          console.log(`[CLEANUP] Meeting ${meeting.meeting_id} skipped - no container_ids (raw: ${typeof meeting.container_ids})`);
          continue;
        }

        let allStopped = false;
        try {
          const status = await checkContainersStatus(meeting.bot_server_id, containerIds);
          allStopped = status.allStopped === true;
        } catch (statusErr) {
          console.error(`[CLEANUP] checkContainersStatus FAILED for ${meeting.meeting_id}:`, statusErr.message);
          continue;
        }
        console.log(`[CLEANUP] Meeting ${meeting.meeting_id} (id ${meeting.id}): allStopped=${allStopped}, containers=${containerIds.length}`);
        if (allStopped) {
          try {
            console.log(`[CLEANUP] Calling stopBots for meeting ${meeting.meeting_id} (id ${meeting.id})`);
            await stopBots(meeting.meeting_id, containerIds, meeting.bot_server_id);
          } catch (stopErr) {
            console.error(`[CLEANUP] stopBots FAILED for ${meeting.meeting_id}:`, stopErr.message, stopErr.code);
          }
          await query(
            `UPDATE meetings SET status = 'stopped', stopped_at = NOW() WHERE id = $1`,
            [meeting.id]
          );
          await decreaseUsage(meeting.members_count);
          console.log(`🧹 Auto-marked meeting ${meeting.meeting_id} (id ${meeting.id}) as stopped`);
        } else {
          const timeoutSec = meeting.timeout_seconds || 7200;
          const started = meeting.started_at ? new Date(meeting.started_at) : null;
          const elapsedSec = started ? (Date.now() - started.getTime()) / 1000 : 0;
          if (elapsedSec > timeoutSec + 60) {
            console.log(`[CLEANUP] Meeting ${meeting.meeting_id}: allStopped=false but elapsed ${Math.floor(elapsedSec)}s > timeout ${timeoutSec}s+60, forcing cleanup-by-meeting`);
            try {
              await stopBots(meeting.meeting_id, [], meeting.bot_server_id);
              await query(`UPDATE meetings SET status = 'stopped', stopped_at = NOW() WHERE id = $1`, [meeting.id]);
              await decreaseUsage(meeting.members_count);
              console.log(`🧹 Force-cleaned meeting ${meeting.meeting_id} (id ${meeting.id})`);
            } catch (e) {
              console.error(`[CLEANUP] Force cleanup failed:`, e.message);
            }
          } else {
            console.log(`[CLEANUP] Meeting ${meeting.meeting_id}: containers still running, skip`);
          }
        }
      }
    } catch (error) {
      console.error('Error in checkAndCleanupStoppedMeetings:', error);
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
    
    // Cleanup every 10 seconds - update meeting status shortly after host ends meeting.
    const cleanupIntervalMs = 10000;
    this.cleanupInterval = setInterval(() => {
      this.checkAndCleanupStoppedMeetings().catch(e => console.error('[CLEANUP] Error:', e.message));
    }, cleanupIntervalMs);
    
    // Run cleanup once after startup (catch any exited containers from before restart)
    setTimeout(() => {
      console.log('[CLEANUP] Initial run after startup...');
      this.checkAndCleanupStoppedMeetings().catch(e => console.error('[CLEANUP] Init error:', e.message));
    }, 5000);
    
    console.log(`⏰ Scheduler: cron every minute, cleanup every ${Math.floor(cleanupIntervalMs / 1000)}s`);
  }
  
  /**
   * Stop the scheduler
   */
  stop() {
    if (this.cronJob) {
      this.cronJob.stop();
      this.cronJob = null;
    }
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
    this.isRunning = false;
    console.log('Scheduler stopped');
  }
}

// Export singleton instance
const scheduler = new Scheduler();

module.exports = scheduler;
