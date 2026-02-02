# Video Icon - Zoom Official Sample Analysis

From [meetingsdk-linux-raw-recording-sample](https://github.com/zoom/meetingsdk-linux-raw-recording-sample)

## Flow (SendVideoRawData)

### 1. Join params
```cpp
withoutloginParam.isVideoOff = false;
withoutloginParam.isAudioOff = false;  // They join with audio ON
```

### 2. Video settings (when SendVideoRawData)
```cpp
withoutloginParam.isVideoOff = false;
pVideoContext->EnableAutoTurnOffVideoWhenJoinMeeting(false);
```

### 3. Start raw sending - CheckAndStartRawSending()
```cpp
// 1. Create video source with FILE PATH (mp4)
ZoomSDKVideoSource* virtual_camera_video_source = new ZoomSDKVideoSource(DEFAULT_VIDEO_SOURCE);

// 2. Set external source
p_videoSourceHelper->setExternalVideoSource(virtual_camera_video_source);

// 3. IMMEDIATELY call UnmuteVideo - NO wait for onStartSend!
IMeetingVideoController* meetingController = m_pMeetingService->GetMeetingVideoController();
meetingController->UnmuteVideo();
```

### 4. When called
- From **onInMeeting** callback (when meeting status = INMEETING)
- NOT from onJoin - they use meeting status listener

### 5. turnOnSendVideoAndAudio / turnOffSendVideoandAudio
```cpp
// ON
meetingVidController->UnmuteVideo();

// OFF  
meetingVidController->MuteVideo();
```

## Differences vs our implementation

| Aspect | Zoom Sample | Our implementation |
|--------|-------------|--------------------|
| UnmuteVideo timing | **Immediately** after setExternalVideoSource | Wait for onStartSend in thread |
| Video source | MP4 file (ZoomSDKVideoSource with path) | Manual black frames in onStartSend |
| Where called | onInMeeting | onJoin |
| isAudioOff | false (join with audio on) | true (join muted) |

## Potential fixes to try

1. **Call UnmuteVideo immediately** – Right after setExternalVideoSource(), before waiting for onStartSend. Official sample does not wait.

2. **Try real video file** – Use a minimal black-frame MP4 as video source instead of manual send. Their ZoomSDKVideoSource reads from file in onStartSend.

3. **Call from meeting status** – Start video setup when status becomes INMEETING instead of only in onJoin.

4. **Event handlers** – Sample uses MeetingParticipantsCtrlEventListener (host/cohost), MeetingRecordingCtrlEventListener (recording permission), MeetingReminderEventListener.
