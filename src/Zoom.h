#ifndef MEETING_SDK_LINUX_SAMPLE_ZOOM_H
#define MEETING_SDK_LINUX_SAMPLE_ZOOM_H

#include <iostream>
#include <cstring>
#include <chrono>
#include <thread>
#include <string>
#include <sstream>
#include <cstdlib>
#include <atomic>

#include <jwt-cpp/jwt.h>

#include "Config.h"
#include "util/Singleton.h"
#include "util/Log.h"


#include "zoom_sdk.h"
#include "rawdata/zoom_rawdata_api.h"
#include "rawdata/rawdata_renderer_interface.h"

#include "meeting_service_components/meeting_audio_interface.h"
#include "meeting_service_components/meeting_participants_ctrl_interface.h"
#include "meeting_service_components/meeting_video_interface.h"
#include "setting_service_interface.h"

#include "events/AuthServiceEvent.h"
#include "events/MeetingServiceEvent.h"
#include "events/MeetingReminderEvent.h"
#include "events/MeetingRecordingCtrlEvent.h"

#include "raw_record/ZoomSDKRendererDelegate.h"
#include "raw_record/ZoomSDKAudioRawDataDelegate.h"

#include "raw_send/ZoomSDKVideoSource.h"

using namespace std;
using namespace jwt;
using namespace ZOOMSDK;

typedef chrono::time_point<chrono::system_clock> time_point;

class Zoom : public Singleton<Zoom> {

    friend class Singleton<Zoom>;

    Config m_config;

    string m_jwt;

    time_point m_iat;
    time_point m_exp;

    IMeetingService* m_meetingService;
    ISettingService* m_settingService;
    IAuthService* m_authService;

    IZoomSDKRenderer* m_videoHelper;
    ZoomSDKRendererDelegate* m_renderDelegate;

    IZoomSDKAudioRawDataHelper* m_audioHelper;
    ZoomSDKAudioRawDataDelegate* m_audioSource;

    ZoomSDKVideoSource* m_videoSource;
    bool m_cameraSelected = false;
    int m_authRetryCount = 0;
    std::atomic<bool> m_authCallbackReceived{false};
    std::atomic<int> m_authRequestGeneration{0};

    SDKError createServices();
    void generateJWT(const string& key, const string& secret);
    SDKError submitAuthRequest();
    void startAuthWatchdog(int generation);
    bool selectCameraDevice();
    void ensureVideoCapabilityForDesktop();
    bool shouldUseRawVideoSource() const;
    bool shouldUseCameraDevice() const;
    bool shouldUseDirectAudioOffJoin() const;

    /**
     * Callback fired when the SDK authenticates the credentials
    */
    function<void()> onAuth = [&]() {
        auto e = isMeetingStart() ? start() : join();
        string action = isMeetingStart() ? "start" : "join";
        
        if(hasError(e, action + " a meeting")) exit(e);
    };

    /**
     * Callback fires when the app joins the meeting
    */
    function<void()> onJoin = [&]() {
        bool useRawVideo = shouldUseRawVideoSource();
        bool useCamera = shouldUseCameraDevice() && m_cameraSelected;
        bool isAudioOnly = m_config.useRawAudio() && !useRawVideo && !useCamera;
        bool wantVideoIconOnly = m_config.videoIconOnly() || isAudioOnly;
        bool directAudioOffJoin = isAudioOnly && shouldUseDirectAudioOffJoin();

        if (directAudioOffJoin) {
            Log::info("Audio fast-join: keeping audio/video OFF and skipping VoIP/video capability registration");
            return;
        }

        auto* reminderController = m_meetingService->GetMeetingReminderController();
        reminderController->SetEvent(new MeetingReminderEvent());

        // Join VoIP audio so microphone icon appears (then mute immediately)
        // This must be done in onJoin callback to ensure it always happens
        auto* audioCtl = m_meetingService->GetMeetingAudioController();
        if (audioCtl) {
            Log::info("Joining VoIP audio to show microphone icon...");
            auto voipErr = audioCtl->JoinVoip();
            if (hasError(voipErr, "join VoIP")) {
                Log::error("Failed to join VoIP audio");
            } else {
                Log::success("Joined VoIP audio - will mute immediately");
                // Wait a bit for audio to initialize before muting
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
            }
        }

        // Aggressively mute audio on join - prevent any audio join
        if (audioCtl) {
            auto resolveSelfUserId = [&]() -> unsigned int {
                auto* participantCtl = m_meetingService->GetMeetingParticipantsController();
                if (!participantCtl) return 0;
                auto participantsList = participantCtl->GetParticipantsList();
                if (!participantsList || participantsList->GetCount() <= 0) return 0;
                return participantsList->GetItem(0);
            };

            bool mutedOnJoin = false;
            for (int attempt = 0; attempt < 6; attempt++) {
                const unsigned int myUserID = resolveSelfUserId();
                if (myUserID > 0) {
                    SDKError muteErr = audioCtl->MuteAudio(myUserID, false);
                    if (!hasError(muteErr)) {
                        mutedOnJoin = true;
                        Log::success("Audio muted on join (user ID: " + to_string(myUserID) + ")");
                        break;
                    }
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(400));
            }

            // Keep a short background enforcement window (avoids long-running mute loops per bot).
            if (!mutedOnJoin) {
                Log::info("Initial mute not confirmed; applying short background mute enforcement");
            }
            thread([&, audioCtl, resolveSelfUserId]() {
                for (int i = 0; i < 4; i++) {
                    std::this_thread::sleep_for(std::chrono::seconds(3));
                    const unsigned int uid = resolveSelfUserId();
                    if (uid > 0) {
                        SDKError err = audioCtl->MuteAudio(uid, false);
                        if (!hasError(err)) {
                            break;
                        }
                    }
                }
            }).detach();
        }

        // Setup video: raw video source, v4l2 camera, or icon-only capability
        Log::info("Video mode: raw=" + string(useRawVideo ? "true" : "false") +
                  ", camera=" + string(useCamera ? "true" : "false") +
                  ", iconOnly=" + string(wantVideoIconOnly ? "true" : "false"));

        if (useRawVideo) {
            Log::info("Calling setupVideoSending()...");
            setupVideoSending();
        } else if (wantVideoIconOnly) {
            Log::info("Ensuring video capability for desktop icon...");
            ensureVideoCapabilityForDesktop();
        } else if (useCamera) {
            Log::info("Camera device selected - SDK will publish camera video");
        } else if (!m_config.useRawAudio()) {
            Log::error("No video source configured - video sending will not start");
        }

        // Subscribe to raw audio WITHOUT requesting recording permission
        // This enables JoinVoip() to work (mic icon) without "REC" indicator
        // Note: Subscription might fail if done too early - we'll retry after a delay
        if (m_config.useRawAudio()) {
            // Delay subscription slightly to ensure meeting is fully joined
            thread([&]() {
                std::this_thread::sleep_for(std::chrono::milliseconds(2000));
                m_audioHelper = GetAudioRawdataHelper();
                if (m_audioHelper) {
                    if (!m_audioSource) {
                        auto mixedAudio = !m_config.separateParticipantAudio();
                        auto transcribe = m_config.transcribe();
                        m_audioSource = new ZoomSDKAudioRawDataDelegate(mixedAudio, transcribe);
                        m_audioSource->setDir(m_config.audioDir());
                        m_audioSource->setFilename(m_config.audioFile());
                    }
                    auto err = m_audioHelper->subscribe(m_audioSource);
                    if (!hasError(err, "subscribe to raw audio")) {
                        Log::info("Subscribed to raw audio (for mic icon) - data will be discarded");
                    } else {
                        Log::info("Raw audio subscription failed (non-critical) - mic icon may not appear");
                    }
                }
            }).detach();
        }

        if (!m_config.useRawVideo() || m_config.videoIconOnly())
            return;

        function<void(bool)> onRecordingPrivilegeChanged = [&](bool canRec) {
            if (!canRec) {
                Log::error("Failed to get recording privilege");
                return;
            }

            startRawRecording();
        };

        auto recCtl = m_meetingService->GetMeetingRecordingController();
        auto recordingEvent = new MeetingRecordingCtrlEvent(onRecordingPrivilegeChanged);
        recCtl->SetEvent(recordingEvent);

        SDKError err = recCtl->CanStartRawRecording();

        if (hasError(err)) {
            Log::info("requesting local recording privilege");
            recCtl->RequestLocalRecordingPrivilege();
        }
    };

    /**
     * Callback fired when meeting ends (host ended for all / bot disconnected)
     * Exit process so container stops automatically.
    */
    function<void()> onMeetingEnd = [&]() {
        Log::info("Meeting ended event received. Exiting bot process.");
        std::_Exit(0);
    };

public:
    Zoom() {};
    SDKError init();
    SDKError auth();
    SDKError config(int ac, char** av);

    SDKError join();
    SDKError start();
    SDKError leave();

    SDKError clean();
    
    SDKError setupVideoSending();  // Setup video sending without recording

    SDKError startRawRecording();
    SDKError stopRawRecording();

    bool isMeetingStart();

    static bool hasError(SDKError e, const string& action="");

};

#endif //MEETING_SDK_LINUX_SAMPLE_ZOOM_H
