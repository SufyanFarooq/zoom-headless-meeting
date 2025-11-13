# 📹 Video Sending Requirements & Implementation Plan

## 🎯 Goal
Enable bots to join Zoom meetings with **video enabled** and **send video from a file**.

---

## 📋 Current Status Analysis

### ✅ What's Already Working:
1. **Video joining**: `isVideoOff = false` (line 131 in Zoom.cpp) - Video is enabled when joining
2. **Video recording**: Code can RECEIVE and record video (RawVideo output)
3. **Video source infrastructure**: `ZoomSDKVideoSource` class exists

### ❌ What's Missing:
1. **Video sending code is COMMENTED OUT** (lines 247-267 in Zoom.cpp)
2. **No video file reading**: `ZoomSDKVideoSource` doesn't read video files
3. **No frame sending logic**: No code to read frames and send to Zoom SDK
4. **Config missing input file option**: Only output file exists, no input file option

---

## 🔍 Code Analysis

### Current Code Structure:

**Zoom.cpp (lines 247-267) - COMMENTED:**
```cpp
/*      auto* videoSourceHelper = GetRawdataVideoSourceHelper();
        if (!videoSourceHelper) {
            Log::error("Initializing Video Source Helper");
            return SDKERR_UNINITIALIZATION;
        }

        err = videoSourceHelper->setExternalVideoSource(m_videoSource);
        if (hasError(err, "set video source"))
            return err;

        auto* videoSettings = m_settingService->GetVideoSettings();
        videoSettings->EnableAutoTurnOffVideoWhenJoinMeeting(false);

       auto* sender = m_videoSource->getSender();
        SDKError e;
        do {
            Log::info("attempting unmute");
            auto* videoCtl = m_meetingService->GetMeetingVideoController();
            e = videoCtl->UnmuteVideo();
            if (hasError(e, "unmute")) sleep(1);
        } while (hasError(e));*/
```

**ZoomSDKVideoSource.cpp** - Has sender but no file reading:
- ✅ Has `m_videoSender` (IZoomSDKVideoSender*)
- ✅ Has `onStartSend()` callback
- ❌ No video file reading
- ❌ No frame sending loop

**Config.cpp** - Only output file:
- ✅ `m_videoFile` exists (for output/recording)
- ❌ No input video file option

---

## 📝 Requirements

### 1. Configuration Changes

**Add to Config.h:**
```cpp
string m_videoInputFile;  // Input video file to send
```

**Add to Config.cpp:**
```cpp
// Option for input video file
m_app.add_option("--video-input", m_videoInputFile, "Input video file to send");
```

**Update sample.config.toml:**
```toml
[RawVideo]
file="meeting-video.mp4"        # Output file (recording)
input="input-video.mp4"          # Input file (sending) - NEW
```

### 2. Video File Reading

**Add to ZoomSDKVideoSource.h:**
```cpp
#include <opencv2/videoio.hpp>
#include <thread>
#include <atomic>

cv::VideoCapture m_videoCapture;
string m_videoFilePath;
thread m_sendingThread;
atomic<bool> m_isSending;
```

**Add to ZoomSDKVideoSource.cpp:**
```cpp
void ZoomSDKVideoSource::startSending(const string& videoFilePath) {
    m_videoFilePath = videoFilePath;
    m_videoCapture.open(videoFilePath);
    
    if (!m_videoCapture.isOpened()) {
        Log::error("Failed to open video file: " + videoFilePath);
        return;
    }
    
    // Start sending thread
    m_isSending = true;
    m_sendingThread = thread(&ZoomSDKVideoSource::sendFramesLoop, this);
}

void ZoomSDKVideoSource::sendFramesLoop() {
    cv::Mat frame;
    int fps = 30; // Default FPS
    auto frameTime = chrono::milliseconds(1000 / fps);
    
    while (m_isSending && m_videoSender && m_videoCapture.isOpened()) {
        auto start = chrono::steady_clock::now();
        
        if (!m_videoCapture.read(frame)) {
            // Loop video
            m_videoCapture.set(cv::CAP_PROP_POS_FRAMES, 0);
            continue;
        }
        
        // Convert BGR to I420 (YUV format)
        // Send frame via m_videoSender->SendVideoFrame()
        
        auto elapsed = chrono::steady_clock::now() - start;
        auto sleepTime = frameTime - elapsed;
        if (sleepTime.count() > 0) {
            this_thread::sleep_for(sleepTime);
        }
    }
}
```

### 3. Uncomment and Fix Video Sending Code

**In Zoom.cpp (startRawRecording):**
```cpp
if (m_config.useRawVideo() && !m_config.videoInputFile().empty()) {
    // Uncomment and fix the video sending code
    auto* videoSourceHelper = GetRawdataVideoSourceHelper();
    if (!videoSourceHelper) {
        Log::error("Initializing Video Source Helper");
        return SDKERR_UNINITIALIZE;
    }

    err = videoSourceHelper->setExternalVideoSource(m_videoSource);
    if (hasError(err, "set video source"))
        return err;

    auto* videoSettings = m_settingService->GetVideoSettings();
    videoSettings->EnableAutoTurnOffVideoWhenJoinMeeting(false);
    
    // Start sending video from file
    m_videoSource->startSending(m_config.videoInputFile());
    
    // Unmute video
    auto* videoCtl = m_meetingService->GetMeetingVideoController();
    SDKError e;
    do {
        Log::info("attempting unmute video");
        e = videoCtl->UnmuteVideo();
        if (hasError(e, "unmute")) sleep(1);
    } while (hasError(e));
}
```

### 4. Frame Format Conversion

**Zoom SDK requires I420 (YUV) format:**
- Read frame from file (BGR/RGB)
- Convert to I420 format
- Send via `m_videoSender->SendVideoFrame()`

---

## 🛠️ Implementation Steps

### Step 1: Add Config Support
- [ ] Add `m_videoInputFile` to Config.h
- [ ] Add CLI option in Config.cpp
- [ ] Add getter method `videoInputFile()`
- [ ] Update sample.config.toml

### Step 2: Implement Video File Reading
- [ ] Add OpenCV VideoCapture to ZoomSDKVideoSource
- [ ] Implement `startSending()` method
- [ ] Implement `sendFramesLoop()` thread
- [ ] Add frame rate control (30 FPS)

### Step 3: Implement Frame Sending
- [ ] Convert BGR to I420 format
- [ ] Call `m_videoSender->SendVideoFrame()` with correct format
- [ ] Handle video looping (restart when end reached)

### Step 4: Uncomment and Fix Video Sending Code
- [ ] Uncomment lines 247-267 in Zoom.cpp
- [ ] Add video input file check
- [ ] Fix error handling
- [ ] Test video unmute

### Step 5: Testing
- [ ] Test with 1 bot locally
- [ ] Verify video appears in Zoom meeting
- [ ] Check frame rate and quality
- [ ] Test video looping

---

## 📦 Dependencies

### Already Available:
- ✅ OpenCV (used in ZoomSDKRendererDelegate)
- ✅ Zoom SDK video source helper
- ✅ Thread support

### May Need:
- OpenCV video codec support (H.264, MP4)
- Frame format conversion library (or manual conversion)

---

## 🎬 Video File Requirements

### Supported Formats:
- MP4 (H.264)
- AVI
- MOV

### Recommended Settings:
- **Resolution**: 1280x720 (720p) or 1920x1080 (1080p)
- **Frame Rate**: 30 FPS
- **Codec**: H.264
- **Format**: MP4

### File Location:
- Place video file in project root or `bot-data/` directory
- Reference in config.toml: `input="path/to/video.mp4"`

---

## 🧪 Testing Plan

### Local Test (1 Bot):
1. Prepare test video file (720p, 30fps, MP4)
2. Update config.toml with video input path
3. Build and run: `docker compose up`
4. Join Zoom meeting
5. Verify:
   - ✅ Bot appears with video
   - ✅ Video plays correctly
   - ✅ Frame rate is smooth
   - ✅ Video loops when finished

### Expected Output:
```
✅ configure
✅ initialize
✅ authorize
⏳ connecting to the meeting
✅ connected
✅ video source initialized
✅ starting video send from: input-video.mp4
✅ video unmuted
```

---

## ❓ Questions to Discuss

1. **Video Source**: 
   - Single video file for all bots? Or different videos per bot?
   - Should video loop automatically?

2. **Frame Rate**:
   - Fixed 30 FPS or match video file FPS?

3. **Resolution**:
   - Match video file resolution or scale to 720p/1080p?

4. **Multiple Bots**:
   - Same video for all bots or different videos?
   - How to handle video file paths in Docker containers?

5. **Video Format**:
   - Prefer MP4, or support multiple formats?

---

## 📚 References

- Zoom SDK Video Source Helper: `rawdata/rawdata_video_source_helper_interface.h`
- OpenCV VideoCapture: https://docs.opencv.org/
- I420 Format: YUV 4:2:0 planar format

---

## ✅ Next Steps

1. **Discuss requirements** (video file format, looping, etc.)
2. **Implement config changes** (add video input option)
3. **Implement video file reading** (OpenCV VideoCapture)
4. **Implement frame sending** (I420 conversion + SendVideoFrame)
5. **Uncomment and fix video sending code**
6. **Test with 1 bot locally**

