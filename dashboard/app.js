// API Base URL
// In production (Docker), API is proxied through nginx at /api
// In development, use full URL
const API_BASE_URL = window.location.hostname === 'localhost' && window.location.port === '8080' 
    ? 'http://localhost:3000/api' 
    : '/api';

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    loadMeetings();
    loadSchedules();
    loadUsage();
    
    // Refresh every 10 seconds
    setInterval(() => {
        loadMeetings();
        loadSchedules();
        loadUsage();
    }, 10000);
    
    // Form submission
    const meetingForm = document.getElementById('meetingForm');
    const addNamesForm = document.getElementById('addNamesForm');
    const totalMembersInput = document.getElementById('totalMembers');
    const videoCountInput = document.getElementById('videoCount');
    const audioCountInput = document.getElementById('audioCount');
    
    if (!meetingForm || !addNamesForm || !totalMembersInput || !videoCountInput || !audioCountInput) {
        console.error('Required form elements not found. Please refresh the page.');
        return;
    }
    
    meetingForm.addEventListener('submit', handleFormSubmit);
    addNamesForm.addEventListener('submit', handleAddName);
    
    // Members input validation
    totalMembersInput.addEventListener('input', validateTotalMembers);
    videoCountInput.addEventListener('input', validateVideoAudio);
    audioCountInput.addEventListener('input', validateVideoAudio);
});

// Load active meetings
async function loadMeetings() {
    try {
        const response = await fetch(`${API_BASE_URL}/meetings?status=active`);
        const data = await response.json();
        
        const tbody = document.getElementById('meetingsTableBody');
        tbody.innerHTML = '';
        
        if (data.meetings && data.meetings.length > 0) {
            data.meetings.forEach((meeting, index) => {
                const row = tbody.insertRow();
                row.innerHTML = `
                    <td>${index + 1}</td>
                    <td>${meeting.meeting_id}</td>
                    <td>${meeting.members_count}</td>
                    <td>${meeting.video_count || 0}</td>
                    <td>${meeting.audio_count || 0}</td>
                    <td>${formatDate(meeting.started_at)}</td>
                    <td>${meeting.timeout_seconds}s</td>
                    <td>${meeting.name_type}</td>
                    <td>${meeting.meeting_type}</td>
                    <td>
                        <button class="btn-action" onclick="stopMeeting(${meeting.id})" id="stop-btn-${meeting.id}">Stop</button>
                    </td>
                `;
            });
        } else {
            tbody.innerHTML = '<tr><td colspan="10" class="no-data">No active meetings</td></tr>';
        }
    } catch (error) {
        console.error('Error loading meetings:', error);
    }
}

// Load scheduled tasks
async function loadSchedules() {
    try {
        const response = await fetch(`${API_BASE_URL}/schedules?status=pending`);
        const data = await response.json();
        
        const tbody = document.getElementById('schedulesTableBody');
        tbody.innerHTML = '';
        
        if (data.schedules && data.schedules.length > 0) {
            data.schedules.forEach(schedule => {
                const row = tbody.insertRow();
                // scheduled_time_ist is already in IST format (YYYY-MM-DDTHH:mm)
                // Parse it properly - treat as IST timezone
                let scheduledTime;
                try {
                    // Format: "2025-11-24T04:41" (IST)
                    const [datePart, timePart] = schedule.scheduled_time_ist.split('T');
                    if (datePart && timePart) {
                        // Create date treating as IST (UTC+5:30)
                        const [year, month, day] = datePart.split('-').map(Number);
                        const [hours, minutes] = timePart.split(':').map(Number);
                        // Create UTC date and add 5:30 to get IST
                        scheduledTime = new Date(Date.UTC(year, month - 1, day, hours, minutes, 0, 0));
                        scheduledTime.setUTCHours(scheduledTime.getUTCHours() - 5);
                        scheduledTime.setUTCMinutes(scheduledTime.getUTCMinutes() - 30);
                    } else {
                        scheduledTime = new Date(schedule.scheduled_time_ist);
                    }
                } catch (e) {
                    console.error('Error parsing scheduled time:', e, schedule.scheduled_time_ist);
                    scheduledTime = new Date(schedule.scheduled_time_ist);
                }
                
                row.innerHTML = `
                    <td>${schedule.meeting_id}</td>
                    <td>${schedule.members_count}</td>
                    <td>${schedule.name_type}</td>
                    <td>${schedule.meeting_type}</td>
                    <td>${formatDateTime(scheduledTime)}</td>
                    <td>${schedule.status}</td>
                    <td>
                        <button class="btn-action" onclick="cancelSchedule(${schedule.id})">Cancel</button>
                    </td>
                `;
            });
        } else {
            tbody.innerHTML = '<tr><td colspan="7" class="no-data">No scheduled tasks</td></tr>';
        }
    } catch (error) {
        console.error('Error loading schedules:', error);
    }
}

// Load usage statistics
async function loadUsage() {
    try {
        const response = await fetch(`${API_BASE_URL}/usage`);
        const data = await response.json();
        
        if (data.usage) {
            const { submitted, remaining, limit } = data.usage;
            const submittedPercent = (submitted / limit) * 100;
            
            document.getElementById('usageText').textContent = `Usage: ${submitted} / ${limit}`;
            document.getElementById('usageChart').style.setProperty('--submitted-percent', `${submittedPercent}%`);
        }
    } catch (error) {
        console.error('Error loading usage:', error);
    }
}

// Handle form submission
async function handleFormSubmit(e) {
    e.preventDefault();
    
    const totalMembersEl = document.getElementById('totalMembers');
    const videoCountEl = document.getElementById('videoCount');
    const audioCountEl = document.getElementById('audioCount');
    
    if (!totalMembersEl || !videoCountEl || !audioCountEl) {
        alert('Form elements not found. Please refresh the page.');
        console.error('Form elements missing:', { totalMembersEl, videoCountEl, audioCountEl });
        return;
    }
    
    const totalMembers = parseInt(totalMembersEl.value) || 0;
    const videoCount = parseInt(videoCountEl.value) || 0;
    const audioCount = parseInt(audioCountEl.value) || 0;
    
    // Validate video + audio = total
    if (!validateVideoAudioCounts(totalMembers, videoCount, audioCount)) {
        console.error('Validation failed:', { totalMembers, videoCount, audioCount });
        return;
    }
    
    console.log('Form submitting with data:', { totalMembers, videoCount, audioCount });
    
    // Get all form elements with null checks
    const meetingIdEl = document.getElementById('meetingId');
    const passwordEl = document.getElementById('password');
    const nameTypeEl = document.getElementById('nameType');
    const meetingTypeEl = document.getElementById('meetingType');
    const timeoutEl = document.getElementById('timeout');
    
    if (!meetingIdEl || !passwordEl || !nameTypeEl || !meetingTypeEl) {
        alert('Required form fields not found. Please refresh the page.');
        console.error('Form fields missing');
        return;
    }
    
    const formData = {
        meetingId: meetingIdEl.value,
        password: passwordEl.value,
        membersCount: totalMembers,
        videoCount: videoCount,
        audioCount: audioCount,
        nameType: nameTypeEl.value,
        meetingType: meetingTypeEl.value,
        timeoutSeconds: parseInt(timeoutEl?.value) || 7200
    };
    
    // Check if scheduling is enabled
    const enableScheduleEl = document.getElementById('enableSchedule');
    const scheduledTimeEl = document.getElementById('scheduledTime');
    const enableSchedule = enableScheduleEl?.checked || false;
    const scheduledTime = scheduledTimeEl?.value || '';
    
    // Disable submit button and show loading
    const submitButton = document.querySelector('button[type="submit"]');
    const originalButtonText = submitButton?.textContent || 'SUBMIT';
    if (submitButton) {
        submitButton.disabled = true;
        submitButton.textContent = 'Loading...';
        submitButton.style.opacity = '0.6';
        submitButton.style.cursor = 'not-allowed';
    }
    
    try {
        if (enableSchedule && scheduledTime) {
            // Create scheduled task
            const scheduleData = {
                ...formData,
                scheduledTimeIST: scheduledTime
            };
            
            const response = await fetch(`${API_BASE_URL}/schedules`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(scheduleData)
            });
            
            const result = await response.json();
            
            if (response.ok) {
                alert('Meeting scheduled successfully!');
                resetForm();
                loadSchedules();
            } else {
                alert(`Error: ${result.error || result.message}`);
            }
        } else {
            // Create meeting immediately
            console.log('Sending request to:', `${API_BASE_URL}/meetings`);
            console.log('Request body:', JSON.stringify(formData));
            
            const response = await fetch(`${API_BASE_URL}/meetings`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData)
            });
            
            console.log('Response status:', response.status);
            const result = await response.json();
            console.log('Response data:', result);
            
            if (response.ok) {
                alert('Meeting created successfully!');
                resetForm();
                loadMeetings();
                loadUsage();
            } else {
                alert(`Error: ${result.error || (result.errors ? result.errors.join(', ') : result.message)}`);
            }
        }
    } catch (error) {
        console.error('Error submitting form:', error);
        alert(`Failed to submit: ${error.message}. Please check browser console for details.`);
    } finally {
        // Re-enable submit button
        if (submitButton) {
            submitButton.disabled = false;
            submitButton.textContent = originalButtonText;
            submitButton.style.opacity = '1';
            submitButton.style.cursor = 'pointer';
        }
    }
}

// Validate total members count
function validateTotalMembers() {
    const totalInput = document.getElementById('totalMembers');
    if (!totalInput) return false;
    
    const totalValue = parseInt(totalInput.value) || 0;
    const errorElement = document.getElementById('totalMembersError');
    
    if (totalValue <= 0 || totalValue % 10 !== 0 || totalValue > 100) {
        if (errorElement) errorElement.textContent = 'Must be divisible by 10 and not zero (max 100)';
        totalInput.style.borderColor = '#ff4444';
        return false;
    } else {
        if (errorElement) errorElement.textContent = '';
        totalInput.style.borderColor = '#3a3a3a';
        return true;
    }
}

// Validate video and audio counts
function validateVideoAudio() {
    const totalMembersEl = document.getElementById('totalMembers');
    const videoCountEl = document.getElementById('videoCount');
    const audioCountEl = document.getElementById('audioCount');
    
    if (!totalMembersEl || !videoCountEl || !audioCountEl) {
        return false;
    }
    
    const totalMembers = parseInt(totalMembersEl.value) || 0;
    const videoCount = parseInt(videoCountEl.value) || 0;
    const audioCount = parseInt(audioCountEl.value) || 0;
    
    return validateVideoAudioCounts(totalMembers, videoCount, audioCount);
}

function validateVideoAudioCounts(totalMembers, videoCount, audioCount) {
    const totalInput = document.getElementById('totalMembers');
    const videoInput = document.getElementById('videoCount');
    const audioInput = document.getElementById('audioCount');
    const totalError = document.getElementById('totalMembersError');
    const videoError = document.getElementById('videoCountError');
    const audioError = document.getElementById('audioCountError');
    
    // Check if all elements exist
    if (!totalInput || !videoInput || !audioInput) {
        console.error('Validation elements not found');
        return false;
    }
    
    // Reset all errors first (only if error elements exist)
    if (totalError) totalError.textContent = '';
    if (videoError) videoError.textContent = '';
    if (audioError) audioError.textContent = '';
    if (totalInput) totalInput.style.borderColor = '#3a3a3a';
    if (videoInput) videoInput.style.borderColor = '#3a3a3a';
    if (audioInput) audioInput.style.borderColor = '#3a3a3a';
    
    let isValid = true;
    
    // Validate total members
    if (isNaN(totalMembers) || totalMembers <= 0) {
        if (totalError) totalError.textContent = 'Total must be greater than 0';
        if (totalInput) totalInput.style.borderColor = '#ff4444';
        isValid = false;
    } else if (totalMembers % 10 !== 0) {
        if (totalError) totalError.textContent = 'Must be divisible by 10';
        if (totalInput) totalInput.style.borderColor = '#ff4444';
        isValid = false;
    } else if (totalMembers > 100) {
        if (totalError) totalError.textContent = 'Maximum 100 members allowed';
        if (totalInput) totalInput.style.borderColor = '#ff4444';
        isValid = false;
    }
    
    // Validate video count
    if (isNaN(videoCount) || videoCount < 0) {
        if (videoError) videoError.textContent = 'Must be 0 or greater';
        if (videoInput) videoInput.style.borderColor = '#ff4444';
        isValid = false;
    }
    
    // Validate audio count
    if (isNaN(audioCount) || audioCount < 0) {
        if (audioError) audioError.textContent = 'Must be 0 or greater';
        if (audioInput) audioInput.style.borderColor = '#ff4444';
        isValid = false;
    }
    
    // Validate sum equals total (only if all individual validations passed)
    if (isValid && totalMembers > 0) {
        if ((videoCount + audioCount) !== totalMembers) {
            if (videoError) videoError.textContent = `Video + Audio (${videoCount + audioCount}) must equal Total (${totalMembers})`;
            if (audioError) audioError.textContent = `Video + Audio (${videoCount + audioCount}) must equal Total (${totalMembers})`;
            if (videoInput) videoInput.style.borderColor = '#ff4444';
            if (audioInput) audioInput.style.borderColor = '#ff4444';
            isValid = false;
        }
    }
    
    return isValid;
}

// Stop meeting
async function stopMeeting(meetingId) {
    if (!confirm('Are you sure you want to stop this meeting?')) {
        return;
    }
    
    // Find the stop button and disable it
    const stopButton = document.getElementById(`stop-btn-${meetingId}`) || 
                       document.querySelector(`button[onclick*="stopMeeting(${meetingId})"]`);
    
    if (!stopButton) {
        console.warn('Stop button not found for meeting:', meetingId);
    }
    
    const originalText = stopButton?.textContent || 'Stop';
    const originalDisabled = stopButton?.disabled || false;
    
    if (stopButton) {
        stopButton.disabled = true;
        stopButton.textContent = 'Stopping...';
        stopButton.style.opacity = '0.6';
        stopButton.style.cursor = 'not-allowed';
    }
    
    try {
        // Use AbortController for timeout (5 minutes for large batches)
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 300000); // 5 minutes
        
        const response = await fetch(`${API_BASE_URL}/meetings/${meetingId}`, {
            method: 'DELETE',
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        const result = await response.json();
        
        if (response.ok) {
            // Show success message
            if (stopButton) {
                stopButton.textContent = 'Stopped';
                stopButton.style.backgroundColor = '#28a745';
            }
            
            // Wait a bit before reloading to show the "Stopped" state
            setTimeout(() => {
                loadMeetings();
                loadUsage();
            }, 1000);
        } else {
            alert(`Error: ${result.error || result.message}`);
            // Restore button state on error
            if (stopButton) {
                stopButton.disabled = originalDisabled;
                stopButton.textContent = originalText;
                stopButton.style.opacity = '';
                stopButton.style.cursor = '';
                stopButton.style.backgroundColor = '';
            }
        }
    } catch (error) {
        console.error('Error stopping meeting:', error);
        
        // Check if it's a timeout or abort
        if (error.name === 'AbortError' || error.message?.includes('timeout')) {
            // Meeting might still be stopping in background
            alert('Stop request is taking longer than expected. The meeting is being stopped in the background. Please refresh the page in a moment.');
            // Reload after a delay to check status
            setTimeout(() => {
                loadMeetings();
                loadUsage();
            }, 3000);
        } else {
            alert('Failed to stop meeting. Please try again.');
            // Restore button state on error
            if (stopButton) {
                stopButton.disabled = originalDisabled;
                stopButton.textContent = originalText;
                stopButton.style.opacity = '';
                stopButton.style.cursor = '';
                stopButton.style.backgroundColor = '';
            }
        }
    }
}

// Cancel schedule
async function cancelSchedule(scheduleId) {
    if (!confirm('Are you sure you want to cancel this scheduled task?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/schedules/${scheduleId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            alert('Scheduled task cancelled!');
            loadSchedules();
        } else {
            alert(`Error: ${result.error || result.message}`);
        }
    } catch (error) {
        console.error('Error cancelling schedule:', error);
        alert('Failed to cancel schedule. Please try again.');
    }
}

// Toggle schedule input
function toggleSchedule() {
    const enableSchedule = document.getElementById('enableSchedule').checked;
    const scheduleGroup = document.getElementById('scheduleGroup');
    scheduleGroup.style.display = enableSchedule ? 'block' : 'none';
}

// Reset form
function resetForm() {
    document.getElementById('meetingForm').reset();
    document.getElementById('scheduleGroup').style.display = 'none';
    document.getElementById('enableSchedule').checked = false;
}

// Format date
function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

// Format date time
function formatDateTime(date) {
    if (!date) return '-';
    return date.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

// Download details
function downloadDetails() {
    // TODO: Implement CSV download
    alert('Download feature coming soon!');
}

// Show add names modal
function showAddNamesModal() {
    document.getElementById('addNamesModal').style.display = 'block';
}

// Close add names modal
function closeAddNamesModal() {
    document.getElementById('addNamesModal').style.display = 'none';
}

// Handle add name
async function handleAddName(e) {
    e.preventDefault();
    
    const nameType = document.getElementById('nameTypeSelect').value;
    const name = document.getElementById('customName').value;
    
    try {
        const response = await fetch(`${API_BASE_URL}/names`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, nameType })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            alert(`Name "${name}" added to ${nameType} names!`);
            document.getElementById('addNamesForm').reset();
            closeAddNamesModal();
        } else {
            alert(`Error: ${result.error || result.message}`);
        }
    } catch (error) {
        console.error('Error adding name:', error);
        alert('Failed to add name. Please try again.');
    }
}

