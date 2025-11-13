
#include "ZoomSDKVideoSource.h"
#include <vector>
#include <algorithm>
#include <cctype>

ZoomSDKVideoSource::ZoomSDKVideoSource() : m_isSending(false), m_shouldStop(false), m_isReady(false) {}

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
    m_width = suggest_cap.width;
    m_height = suggest_cap.height;
}

void ZoomSDKVideoSource::onStartSend() {
    Log::info("sender is ready");
    m_isReady = true;
    
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
    
    // If not ready yet, store the path and start when ready
    if (!m_isReady) {
        Log::info("Video source not ready yet, storing path for later: " + videoFilePath);
        m_pendingVideoFilePath = videoFilePath;
        return;
    }
    
    m_videoFilePath = videoFilePath;
    
    // Check file extension
    string extension = "";
    size_t dotPos = videoFilePath.find_last_of(".");
    if (dotPos != string::npos) {
        extension = videoFilePath.substr(dotPos + 1);
        // Convert to lowercase
        transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
    }
    
    // Try to open video file
    m_videoCapture.open(videoFilePath);
    
    // If .H264 or .h264 file fails, try with different backend
    if (!m_videoCapture.isOpened() && (extension == "h264" || extension == "264")) {
        Log::info("Raw H.264 file detected, trying with FFmpeg backend...");
        // Try with explicit backend (FFmpeg)
        m_videoCapture.open(videoFilePath, CAP_FFMPEG);
        
        if (!m_videoCapture.isOpened()) {
            Log::error("Failed to open H.264 file. Raw H.264 streams may not be supported.");
            Log::error("Recommendation: Convert to MP4 container format using:");
            Log::error("  ffmpeg -i input-video.H264 -c:v copy -c:a copy input-video.mp4");
            return;
        }
    } else if (!m_videoCapture.isOpened()) {
        Log::error("Failed to open video file: " + videoFilePath);
        Log::error("Supported formats: MP4, AVI, MOV, MKV");
        Log::error("For H.264 codec, use MP4 container: input-video.mp4");
        return;
    }
    
    // Get video properties
    int videoWidth = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_WIDTH));
    int videoHeight = static_cast<int>(m_videoCapture.get(CAP_PROP_FRAME_HEIGHT));
    double fps = m_videoCapture.get(CAP_PROP_FPS);
    
    if (fps <= 0) fps = 30.0; // Default to 30 FPS if not available
    
    Log::info("Video file opened: " + videoFilePath);
    Log::info("Resolution: " + to_string(videoWidth) + "x" + to_string(videoHeight) + ", FPS: " + to_string(fps));
    
    // Set dimensions
    m_width = videoWidth;
    m_height = videoHeight;
    
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
    if (!m_videoSender || !m_videoCapture.isOpened()) {
        Log::error("Video sender or capture not ready");
        return;
    }
    
    Mat frame;
    const int fps = 15; // 15 FPS for optimal resource usage (can be changed to 30 if needed)
    const auto frameTime = chrono::milliseconds(1000 / fps);
    
    Log::info("Starting video frame sending loop at " + to_string(fps) + " FPS");
    
    while (!m_shouldStop.load() && m_videoSender && m_videoCapture.isOpened()) {
        auto start = chrono::steady_clock::now();
        
        if (!m_videoCapture.read(frame)) {
            // Video ended, loop from beginning
            m_videoCapture.set(CAP_PROP_POS_FRAMES, 0);
            Log::info("Video looped - restarting from beginning");
            continue;
        }
        
        if (frame.empty()) {
            continue;
        }
        
        // Resize to 720p for optimal resource usage (can be changed to 1080p if needed)
        // 720p = 1280x720 (good balance of quality and resources)
        if (frame.cols != 1280 || frame.rows != 720) {
            Mat resizedFrame;
            resize(frame, resizedFrame, Size(1280, 720), 0, 0, INTER_LINEAR);
            frame = resizedFrame;
        }
        
        // Convert BGR to I420 (YUV format required by Zoom SDK)
        int frameLength = frame.cols * frame.rows * 3 / 2; // I420 size
        char* i420Buffer = new char[frameLength];
        
        convertBGRtoI420(frame, i420Buffer, frameLength);
        
        // Send frame to Zoom SDK
        SDKError err = m_videoSender->sendVideoFrame(
            i420Buffer,
            frame.cols,      // width
            frame.rows,      // height
            frameLength,     // frame length
            0,              // rotation
            FrameDataFormat_I420_FULL
        );
        
        delete[] i420Buffer;
        
        if (err != SDKERR_SUCCESS) {
            Log::error("Failed to send video frame: " + to_string(err));
        }
        
        // Maintain 30 FPS timing
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