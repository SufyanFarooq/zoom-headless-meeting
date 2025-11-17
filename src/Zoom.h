#ifndef MEETING_SDK_LINUX_SAMPLE_ZOOM_H
#define MEETING_SDK_LINUX_SAMPLE_ZOOM_H

#include <iostream>
#include <chrono>
#include <thread>
#include <string>
#include <sstream>

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

    SDKError createServices();
    void generateJWT(const string& key, const string& secret);

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
            // Try to mute immediately, then retry if needed
            function<void(int retryCount)> tryMute = [&, audioCtl](int retryCount) {
                auto* participantCtl = m_meetingService->GetMeetingParticipantsController();
                unsigned int myUserID = 0;
                
                if (participantCtl) {
                    auto participantsList = participantCtl->GetParticipantsList();
                    if (participantsList && participantsList->GetCount() > 0) {
                        // Get our own user ID (usually first in list when we join)
                        // Try first participant as it's usually ourselves
                        myUserID = participantsList->GetItem(0);
                        Log::info("Attempting to mute user ID: " + to_string(myUserID));
                    }
                }
                
                if (myUserID > 0) {
                    SDKError muteErr = audioCtl->MuteAudio(myUserID, false);
                    if (!hasError(muteErr)) {
                        Log::success("Audio muted on join (user ID: " + to_string(myUserID) + ")");
                    } else {
                        Log::error("Failed to mute audio on join: " + to_string(muteErr));
                        // Retry after delay if failed
                        if (retryCount < 5) {
                            std::this_thread::sleep_for(std::chrono::milliseconds(500));
                            tryMute(retryCount + 1);
                        }
                    }
                } else {
                    // Retry after delay if user ID not available
                    if (retryCount < 10) {
                        Log::info("User ID not available yet, retrying mute (attempt " + to_string(retryCount + 1) + ")");
                        std::this_thread::sleep_for(std::chrono::milliseconds(500));
                        tryMute(retryCount + 1);
                    } else {
                        Log::error("Could not get user ID for muting after 10 attempts - bot may be unmuted");
                    }
                }
            };
            
            // Start muting attempt immediately
            tryMute(0);
            
            // Also set up periodic muting check to ensure it stays muted
            thread([&, audioCtl]() {
                for (int i = 0; i < 20; i++) {
                    std::this_thread::sleep_for(std::chrono::seconds(2));
                    auto* participantCtl = m_meetingService->GetMeetingParticipantsController();
                    if (participantCtl) {
                        auto participantsList = participantCtl->GetParticipantsList();
                        if (participantsList && participantsList->GetCount() > 0) {
                            unsigned int uid = participantsList->GetItem(0);
                            audioCtl->MuteAudio(uid, false);
                        }
                    }
                }
            }).detach();
        }

        // Setup video sending even if recording is disabled
        string videoFile = m_config.videoInputFile();
        Log::info("Checking video input file: " + (videoFile.empty() ? "EMPTY" : videoFile));
        if (!videoFile.empty()) {
            Log::info("Calling setupVideoSending()...");
            setupVideoSending();
        } else {
            Log::error("Video input file is empty - video sending will not start");
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

        // Only request recording permission if VIDEO recording is needed
        // Audio subscription is done above without permission
        if (!m_config.useRawVideo())  
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
