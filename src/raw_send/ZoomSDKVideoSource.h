
#ifndef MEETINGSDK_HEADLESS_LINUX_SAMPLE_ZOOMSDKVIDEOSOURCE_H
#define MEETINGSDK_HEADLESS_LINUX_SAMPLE_ZOOMSDKVIDEOSOURCE_H

#include "rawdata/rawdata_video_source_helper_interface.h"
#include "../util/Log.h"
#include <opencv2/videoio.hpp>
#include <opencv2/imgproc.hpp>
#include <thread>
#include <atomic>
#include <chrono>

using namespace ZOOMSDK;
using namespace std;
using namespace cv;

struct Frame {
    char* data;
    unsigned int width;
    unsigned int height;
    unsigned int len;
};

class ZoomSDKVideoSource : public IZoomSDKVideoSource    {
    void onInitialize(IZoomSDKVideoSender* sender, IList<VideoSourceCapability >* support_cap_list, VideoSourceCapability& suggest_cap) override;
    void onPropertyChange(IList<VideoSourceCapability >* support_cap_list, VideoSourceCapability suggest_cap) override;
    void onStartSend() override;
    void onStopSend() override;
    void onUninitialized() override;

    IZoomSDKVideoSender* m_videoSender;
    unsigned int m_height;
    unsigned int m_width;
    bool m_isReady;
    
    VideoCapture m_videoCapture;
    string m_videoFilePath;
    thread m_sendingThread;
    atomic<bool> m_isSending;
    atomic<bool> m_shouldStop;
    string m_pendingVideoFilePath;  // Store video file path until ready

public:
    ZoomSDKVideoSource();
    ~ZoomSDKVideoSource();

    IZoomSDKVideoSender* getSender() const;

    bool isReady();
    void setWidth(const unsigned int& width);
    void setHeight(const unsigned int& height);
    
    void startSending(const string& videoFilePath);
    void stopSending();
    
private:
    void sendFramesLoop();
    void convertBGRtoI420(const Mat& bgrFrame, char* i420Buffer, int& frameLength);
};


#endif //MEETINGSDK_HEADLESS_LINUX_SAMPLE_ZOOMSDKVIDEOSOURCE_H
