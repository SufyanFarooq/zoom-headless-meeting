
#include "ZoomSDKVideoSource.h"
#include <vector>
#include <algorithm>
#include <cctype>
#include <unistd.h>
#include <cstdlib>
#include <fstream>

ZoomSDKVideoSource::ZoomSDKVideoSource()
    : m_videoSender(nullptr),
      m_height(0),
      m_width(0),
      m_isReady(false),
      m_isSending(false),
      m_shouldStop(false) {}

ZoomSDKVideoSource::~ZoomSDKVideoSource() {
    stopSending();
}

bool ZoomSDKVideoSource::isReady() {
    return m_isReady;
}

IZoomSDKVideoSender *ZoomSDKVideoSource::getSender() const {
    return m_videoSender;
}

void ZoomSDKVideoSource::onInitialize(IZoomSDKVideoSender *sender,IList <VideoSourceCapability> *support_cap_list,
                                      VideoSourceCapability& suggest_cap){
    m_videoSender = sender;
    Log::success("onInitialize");

}

void ZoomSDKVideoSource::onPropertyChange(IList <VideoSourceCapability> *support_cap_list,
                                          VideoSourceCapability suggest_cap) {
    if (suggest_cap.width > 0 && suggest_cap.height > 0) {
        m_width = suggest_cap.width;
        m_height = suggest_cap.height;
    } else if (m_width == 0 || m_height == 0) {
        // Fallback to safe defaults if SDK suggests invalid dimensions
        m_width = 640;
        m_height = 360;
    }
    
    Log::info("📐 SDK Preferred Video Dimensions: " + to_string(m_width) + "x" + to_string(m_height));
    Log::info("💡 TIP: Re-encode your videos to this resolution to avoid zoom/crop issues");
    
    // If we have video file open, show comparison
    if (m_videoCapture.isOpened() && m_width > 0 && m_height > 0) {
        int videoWidth = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_WIDTH));
        int videoHeight = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_HEIGHT));
        
        if (videoWidth != (int)m_width || videoHeight != (int)m_height) {
            Log::info("⚠️  Current video: " + to_string(videoWidth) + "x" + to_string(videoHeight) + 
                     " - Re-encode to " + to_string(m_width) + "x" + to_string(m_height) + " for best results");
        } else {
            Log::info("✅ Video dimensions match SDK preferred - perfect!");
        }
    }
}

void ZoomSDKVideoSource::onStartSend() {
    Log::info("sender is ready");
    m_isReady = true;
    
    // Wait a bit for sender to fully initialize before starting
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
    // Start sending video if file path was set before we were ready
    if (!m_pendingVideoFilePath.empty()) {
        Log::info("Starting video sending from pending file: " + m_pendingVideoFilePath);
        startSending(m_pendingVideoFilePath);
        m_pendingVideoFilePath.clear();
    }
}

void ZoomSDKVideoSource::onStopSend() {
    Log::info("sender stopped");
    m_isReady = false;
}

void ZoomSDKVideoSource::onUninitialized() {
    m_videoSender = nullptr;
}

void ZoomSDKVideoSource::setWidth(const unsigned int& width) {
    m_width = width;
}

void ZoomSDKVideoSource::setHeight(const unsigned int& height) {
    m_height = height;
}

void ZoomSDKVideoSource::startSending(const string& videoFilePath) {
    if (m_isSending.load()) {
        Log::error("Video sending already in progress");
        return;
    }

    // Test pattern mode (no input file)
    if (videoFilePath.empty() || videoFilePath == "TEST_PATTERN") {
        m_useTestPattern = true;
        m_videoFilePath = "TEST_PATTERN";
        if (m_width == 0 || m_height == 0) {
            m_width = 640;
            m_height = 360;
        }
    } else {
        m_useTestPattern = false;
        m_videoFilePath = videoFilePath;
    }
    
    // If not ready yet, store the path and start when ready
    if (!m_isReady) {
        Log::info("Video source not ready yet, storing path for later: " + videoFilePath);
        m_pendingVideoFilePath = videoFilePath;
        return;
    }
    
    if (!m_useTestPattern) {
        // Check file extension
        string extension = "";
        size_t dotPos = m_videoFilePath.find_last_of(".");
        if (dotPos != string::npos) {
            extension = m_videoFilePath.substr(dotPos + 1);
            // Convert to lowercase
            transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
        }
        
        // Resolve path: if relative, make it absolute
        // Always use /tmp/meeting-sdk-linux-sample as base (Docker container working directory)
        string resolvedPath = m_videoFilePath;
        if (m_videoFilePath[0] != '/') {
            // Relative path - resolve to absolute using known container directory
            resolvedPath = "/tmp/meeting-sdk-linux-sample/" + m_videoFilePath;
            
            // Remove double slashes (in case videoFilePath starts with /)
            size_t pos;
            while ((pos = resolvedPath.find("//")) != string::npos) {
                resolvedPath.replace(pos, 2, "/");
            }
            
            // Also try getcwd() as fallback for debugging
            char* cwd = getcwd(nullptr, 0);
            if (cwd) {
                string cwdPath = string(cwd) + "/" + m_videoFilePath;
                // Remove double slashes
                while ((pos = cwdPath.find("//")) != string::npos) {
                    cwdPath.replace(pos, 2, "/");
                }
                Log::info("Current working directory: " + string(cwd));
                Log::info("Alternative path (from getcwd): " + cwdPath);
                free(cwd);
            }
        }
        
        // Try to open video file with resolved path
        Log::info("Video input file (original): " + m_videoFilePath);
        Log::info("Video input file (resolved): " + resolvedPath);
        Log::info("Attempting to open video file: " + resolvedPath);
        
        // Check if file exists before trying to open
        ifstream fileCheck(resolvedPath);
        if (!fileCheck.good()) {
            Log::error("Video file does not exist: " + resolvedPath);
            Log::error("Please verify the file exists on the server");
            return;
        }
        fileCheck.close();
        
        m_videoCapture.open(resolvedPath);
        
        // If default backend fails, try FFmpeg backend (more reliable for MP4)
        if (!m_videoCapture.isOpened()) {
            Log::info("Default backend failed, trying FFmpeg backend...");
            m_videoCapture.open(resolvedPath, CAP_FFMPEG);
        }
        
        // If .H264 or .h264 file fails, try with different backend
        if (!m_videoCapture.isOpened() && (extension == "h264" || extension == "264")) {
            Log::info("Raw H.264 file detected, trying with FFmpeg backend...");
            m_videoCapture.open(resolvedPath, CAP_FFMPEG);
            
            if (!m_videoCapture.isOpened()) {
                Log::error("Failed to open H.264 file. Raw H.264 streams may not be supported.");
                Log::error("Recommendation: Convert to MP4 container format using:");
                Log::error("  ffmpeg -i input-video.H264 -c:v copy -c:a copy input-video.mp4");
                return;
            }
        } else if (!m_videoCapture.isOpened()) {
            Log::error("Failed to open video file: " + m_videoFilePath);
            Log::error("Resolved path: " + resolvedPath);
            Log::error("Supported formats: MP4, AVI, MOV, MKV");
            Log::error("For H.264 codec, use MP4 container: input-video.mp4");
            Log::error("Troubleshooting:");
            Log::error("  1. Check if file exists: ls -la " + resolvedPath);
            Log::error("  2. Check file permissions");
            Log::error("  3. Verify video format: ffprobe " + resolvedPath);
            return;
        }
        
        // Get video properties
        int videoWidth = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_WIDTH));
        int videoHeight = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_HEIGHT));
        double fps = m_videoCapture.get(CAP_PROP_FPS);
        
        if (fps <= 0) fps = 15.0; // Default to 15 FPS if not available
        
        Log::info("Video file opened: " + m_videoFilePath);
        Log::info("Reading video resolution from file: " + to_string(videoWidth) + "x" + to_string(videoHeight) + ", FPS: " + to_string(fps));
        
        // Set dimensions to native resolution (no scaling)
        m_width = videoWidth;
        m_height = videoHeight;
        m_testFps = fps;
    } else {
        // Test pattern defaults
        if (m_width == 0) m_width = 640;
        if (m_height == 0) m_height = 360;
        m_testFps = 10.0;
        Log::info("Test pattern mode: sending synthetic frames at " + to_string((int)m_width) + "x" + to_string((int)m_height) + " @ " + to_string(m_testFps) + " FPS");
    }
    
    // Start sending thread
    m_shouldStop = false;
    m_isSending = true;
    m_sendingThread = thread(&ZoomSDKVideoSource::sendFramesLoop, this);
}

void ZoomSDKVideoSource::stopSending() {
    if (!m_isSending.load()) {
        return;
    }
    
    m_shouldStop = true;
    m_isSending = false;
    
    if (m_sendingThread.joinable()) {
        m_sendingThread.join();
    }
    
    if (m_videoCapture.isOpened()) {
        m_videoCapture.release();
    }
    
    Log::info("Video sending stopped");
}

void ZoomSDKVideoSource::sendFramesLoop() {
    if (!m_videoSender) {
        Log::error("Video sender not ready");
        return;
    }
    if (!m_useTestPattern && !m_videoCapture.isOpened()) {
        Log::error("Video capture not ready");
        return;
    }
    
    // Wait a bit for video sender to fully initialize
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    
    Mat frame;
    
    // Get FPS: from file or test pattern
    double nativeFps = m_useTestPattern ? m_testFps : m_videoCapture.get(CAP_PROP_FPS);
    if (nativeFps <= 0) nativeFps = 10.0;
    if (nativeFps > 10.0) nativeFps = 10.0; // Cap at 10 FPS
    
    const int fps = static_cast<int>(nativeFps);
    const auto frameTime = chrono::milliseconds(1000 / fps);
    
    Log::info("Starting video frame sending loop at " + to_string(fps) + " FPS");
    
    // Wait for onPropertyChange to set dimensions, or use file dimensions
    int waitCount = 0;
    while ((m_width == 0 || m_height == 0) && waitCount < 20 && !m_shouldStop.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        waitCount++;
    }
    
    if (m_width == 0 || m_height == 0) {
        // Use file dimensions if SDK hasn't set preferred yet
        int fileWidth = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_WIDTH));
        int fileHeight = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_HEIGHT));
        if (m_width == 0) m_width = fileWidth;
        if (m_height == 0) m_height = fileHeight;
        Log::info("⚠️  SDK hasn't called onPropertyChange yet - Using file dimensions: " + to_string(m_width) + "x" + to_string(m_height));
        Log::info("ℹ️  Will wait for SDK to set preferred dimensions via onPropertyChange callback");
    } else {
        Log::info("✅ Using SDK preferred dimensions: " + to_string(m_width) + "x" + to_string(m_height));
        int fileWidth = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_WIDTH));
        int fileHeight = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_HEIGHT));
        if (fileWidth != (int)m_width || fileHeight != (int)m_height) {
            Log::info("⚠️  File dimensions (" + to_string(fileWidth) + "x" + to_string(fileHeight) + ") differ from SDK preferred - will resize");
        }
    }
    
    int consecutiveErrors = 0;
    const int maxConsecutiveErrors = 10;
    
    int patternIndex = 0;
    
    while (!m_shouldStop.load() && m_videoSender && (m_useTestPattern || m_videoCapture.isOpened()) && m_isReady) {
        auto start = chrono::steady_clock::now();
        
        if (m_useTestPattern) {
            frame = makeTestPatternFrame(patternIndex++, m_width, m_height);
        } else {
            if (!m_videoCapture.read(frame)) {
                // Video ended, loop from beginning
                m_videoCapture.set(CAP_PROP_POS_FRAMES, 0);
                Log::info("Video looped - restarting from beginning");
                continue;
            }
            if (frame.empty()) {
                continue;
            }
        }
        
        // NO RESIZING - Send frames exactly as-is from video file
        // User will re-encode videos to match SDK preferred dimensions
        // This reduces CPU load by avoiding runtime resizing
        unsigned int sendWidth = frame.cols;
        unsigned int sendHeight = frame.rows;
        
        // Log if SDK wants different dimensions (for user to know what to encode videos to)
        if (m_width > 0 && m_height > 0 && 
            (m_width != (unsigned int)frame.cols || m_height != (unsigned int)frame.rows)) {
            // Log once per 100 frames to avoid spam
            static int logCounter = 0;
            if (logCounter % 100 == 0) {
                Log::info("ℹ️  Video file: " + to_string(frame.cols) + "x" + to_string(frame.rows) + 
                         ", SDK prefers: " + to_string(m_width) + "x" + to_string(m_height) + 
                         " - Consider re-encoding video to match SDK dimensions");
            }
            logCounter++;
        }
        
        // Calculate I420 buffer size: Y plane (full) + U plane (1/4) + V plane (1/4)
        int frameLength = sendWidth * sendHeight * 3 / 2;
        char* i420Buffer = new char[frameLength];
        
        // Convert BGR to I420 (required by Zoom SDK)
        // Note: OpenCV VideoCapture decodes MP4 to BGR, so conversion is necessary
        convertBGRtoI420(frame, i420Buffer, frameLength);
        
        // Verify video sender is ready before sending
        if (!m_videoSender) {
            Log::error("Video sender not ready, skipping frame");
            delete[] i420Buffer;
            continue;
        }
        
        // Send frame to Zoom SDK at native resolution
        SDKError err = m_videoSender->sendVideoFrame(
            i420Buffer,
            sendWidth,       // width
            sendHeight,      // height
            frameLength,     // frame length
            0,              // rotation
            FrameDataFormat_I420_FULL
        );
        
        delete[] i420Buffer;
        
        if (err != SDKERR_SUCCESS) {
            consecutiveErrors++;
            if (consecutiveErrors <= 5) {
                Log::error("Failed to send video frame: " + to_string(err) + " (width: " + to_string(sendWidth) + ", height: " + to_string(sendHeight) + ", length: " + to_string(frameLength) + ", errors: " + to_string(consecutiveErrors) + ")");
            }
            // If too many consecutive errors, wait a bit before retrying
            if (consecutiveErrors >= maxConsecutiveErrors) {
                Log::error("Too many consecutive errors, waiting before retry...");
                std::this_thread::sleep_for(std::chrono::milliseconds(2000));
                consecutiveErrors = 0;
            }
        } else {
            consecutiveErrors = 0; // Reset on success
        }
        
        // Maintain native FPS timing
        auto elapsed = chrono::steady_clock::now() - start;
        auto sleepTime = frameTime - chrono::duration_cast<chrono::milliseconds>(elapsed);
        if (sleepTime.count() > 0) {
            this_thread::sleep_for(sleepTime);
        }
    }
    
    Log::info("Video sending loop ended");
}

void ZoomSDKVideoSource::convertBGRtoI420(const Mat& bgrFrame, char* i420Buffer, int& frameLength) {
    int width = bgrFrame.cols;
    int height = bgrFrame.rows;
    
    // Convert BGR to YUV (I420 format)
    // I420 is planar: Y plane (full size), then U plane (1/4 size), then V plane (1/4 size)
    Mat yuvFrame;
    cvtColor(bgrFrame, yuvFrame, COLOR_BGR2YUV);
    
    // Split into Y, U, V planes
    vector<Mat> yuvPlanes;
    split(yuvFrame, yuvPlanes);
    
    // I420 format: Y plane (full), U plane (subsampled), V plane (subsampled)
    int ySize = width * height;
    int uvWidth = width / 2;
    int uvHeight = height / 2;
    int uvSize = uvWidth * uvHeight;
    
    // Copy Y plane (full resolution)
    memcpy(i420Buffer, yuvPlanes[0].data, ySize);
    
    // Downsample and copy U plane
    Mat uResized;
    resize(yuvPlanes[1], uResized, Size(uvWidth, uvHeight), 0, 0, INTER_LINEAR);
    memcpy(i420Buffer + ySize, uResized.data, uvSize);
    
    // Downsample and copy V plane
    Mat vResized;
    resize(yuvPlanes[2], vResized, Size(uvWidth, uvHeight), 0, 0, INTER_LINEAR);
    memcpy(i420Buffer + ySize + uvSize, vResized.data, uvSize);
    
    frameLength = ySize + uvSize + uvSize;
}

Mat ZoomSDKVideoSource::makeTestPatternFrame(int frameIndex, int width, int height) {
    Mat img(height, width, CV_8UC3);
    // Simple moving gradient
    int shift = frameIndex % width;
    for (int y = 0; y < height; ++y) {
        Vec3b* row = img.ptr<Vec3b>(y);
        for (int x = 0; x < width; ++x) {
            int v = (x + shift) % 255;
            row[x] = Vec3b((v + y) % 255, (v * 2) % 255, (255 - v) % 255);
        }
    }
    return img;
}
