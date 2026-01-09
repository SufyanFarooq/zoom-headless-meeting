TIMEZONE FIX EXPLANATION
========================

ISSUES IDENTIFIED:
------------------

1. LABEL CONFUSION:
   - Frontend label said "IST Format" but actually sending UTC
   - This was confusing for users and reviewers
   - Fixed: Changed to "Your Local Time" with explanation

2. TIMEZONE HANDLING:
   - Frontend: datetime-local input gives LOCAL time
   - Conversion: JavaScript converts to UTC properly
   - Backend: Expects UTC format (YYYY-MM-DDTHH:mm)
   - Database: Stores as UTC timestamp
   - Scheduler: Runs in UTC timezone

3. UNSCHEDULED MEETING ERROR:
   - Error handling improved
   - Better error messages for bot creation failures
   - More detailed error information

FIXES IMPLEMENTED:
------------------

1. FRONTEND LABEL UPDATE:
   - Changed: "Schedule Task (IST Format):" 
   - To: "Schedule Task (Your Local Time):"
   - Added helper text: "Time will be automatically converted to UTC"

2. TIMEZONE CONVERSION:
   - Frontend properly converts local time to UTC
   - Backend accepts UTC format
   - All times stored in UTC in database
   - Scheduler uses UTC timezone

3. ERROR HANDLING:
   - Better error messages for bot creation failures
   - More detailed error information in development mode
   - Proper error propagation

HOW IT WORKS NOW:
-----------------

SCHEDULED MEETINGS:
1. User selects local time in datetime-local input
2. Frontend converts to UTC: `new Date(scheduledTime).toISOString().slice(0, 16)`
3. Backend receives UTC format: "YYYY-MM-DDTHH:mm"
4. Backend stores in database as UTC timestamp
5. Scheduler runs every minute in UTC timezone
6. When scheduled time arrives (in UTC), bots are created

UNSCHEDULED MEETINGS:
1. User submits form without scheduling
2. Meeting created immediately
3. Bots join right away
4. Error handling improved for better debugging

VERIFICATION:
-------------

To verify timezone handling:
1. Schedule a meeting for 5 minutes from now
2. Check database: scheduled_time_ist should be UTC
3. Wait for scheduled time
4. Bots should join automatically

To test unscheduled meeting:
1. Submit form without enabling schedule
2. Bots should join immediately
3. Check for any errors in console/logs

