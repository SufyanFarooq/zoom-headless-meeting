TIMEZONE ISSUE DIAGNOSIS
========================

PROBLEM REPORTED:
-----------------
- User submitted: 9:55 PM IST
- Payload sent: "2026-01-09T17:55" UTC
- Display shows: 11:25 PM
- Scheduled meeting not executing

ANALYSIS:
---------

1. CONVERSION ISSUE:
   - User enters: 9:55 PM IST (21:55 IST)
   - Expected UTC: 21:55 - 5:30 = 16:25 UTC
   - Actual sent: 17:55 UTC
   - Difference: 1 hour 30 minutes off

2. DISPLAY ISSUE:
   - Backend sends: "2026-01-09T17:55" UTC
   - Display converts: 17:55 UTC + 5:30 = 23:25 IST = 11:25 PM
   - User expected: 9:55 PM
   - Difference: 1 hour 30 minutes off

3. SCHEDULER ISSUE:
   - Scheduled time stored: 17:55 UTC
   - Current time: Need to check
   - Scheduler should execute when 17:55 UTC arrives
   - But if time is wrong, it won't execute correctly

ROOT CAUSE:
-----------
Browser timezone might be different from IST:
- Browser timezone: Pakistan Standard Time (UTC+5:00) or other
- User expects: IST (UTC+5:30)
- Conversion uses browser timezone, not IST

SOLUTION:
---------
1. Fix timezone conversion to be explicit
2. Use UTC consistently
3. Let browser handle display conversion
4. Add timezone info in logs

FIXES APPLIED:
--------------
1. Improved UTC conversion in frontend
2. Better logging for debugging
3. Explicit UTC time extraction

TESTING NEEDED:
---------------
1. Submit schedule with current time + 5 minutes
2. Check payload sent to backend
3. Check database stored time
4. Check display time
5. Wait for scheduled time
6. Verify bots join

