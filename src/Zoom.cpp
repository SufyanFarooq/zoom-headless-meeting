#include "Zoom.h"
#include <thread>
#include <chrono>
#include <algorithm>
#include <cctype>
#include <cstdlib>

using namespace std::chrono;

SDKError Zoom::config(int ac, char** av) {
    auto status = m_config.read(ac, av);
    if (status) {
        Log::error("failed to read configuration");
        return SDKERR_INTERNAL_ERROR;
    }

    return SDKERR_SUCCESS;
}

SDKError Zoom::init() { 
    InitParam initParam;

    auto host = m_config.zoomHost().c_str();

    initParam.strWebDomain = host;
    initParam.strSupportUrl = host;

    initParam.emLanguageID = LANGUAGE_English;

    initParam.enableLogByDefault = true;
    initParam.enableGenerateDump = true;

    auto err = InitSDK(initParam);
    if (hasError(err)) {
        Log::error("InitSDK failed");
        return err;
    }

    return createServices();
}

SDKError Zoom::createServices() {
    auto err = CreateMeetingService(&m_meetingService);
    if (hasError(err)) return err;

    err = CreateSettingService(&m_settingService);
    if (hasError(err)) return err;

    auto meetingServiceEvent = new MeetingServiceEvent();
    meetingServiceEvent->setOnMeetingJoin(onJoin);

    err = m_meetingService->SetEvent(meetingServiceEvent);
    if (hasError(err)) return err;

    return CreateAuthService(&m_authService);
}

static string toLowerCopy(const string& s) {
    string out = s;
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) { return std::tolower(c); });
    return out;
}

bool Zoom::shouldUseCameraDevice() const {
    return m_config.resolvedCameraMode() == "v4l2";
}

bool Zoom::shouldUseRawVideoSource() const {
    return m_config.resolvedCameraMode() == "raw" && !m_config.videoInputFile().empty();
}

bool Zoom::selectCameraDevice() {
    if (!m_settingService) return false;
    if (!shouldUseCameraDevice()) return false;

    auto* videoSettings = m_settingService->GetVideoSettings();
    if (!videoSettings) {
        Log::error("Video settings not available - cannot select camera");
        return false;
    }

    auto* list = videoSettings->GetCameraList();
    if (!list || list->GetCount() == 0) {
        Log::error("No camera devices found by SDK");
        return false;
    }

    string target = toLowerCopy(m_config.cameraName());
    Log::info("Available camera devices:");
    for (int i = 0; i < list->GetCount(); i++) {
        auto* cam = list->GetItem(i);
        if (!cam) continue;
        const zchar_t* name = cam->GetDeviceName();
        const zchar_t* id = cam->GetDeviceId();
        string nameStr = name ? name : "";
        string idStr = id ? id : "";
        Log::info("  - " + nameStr + " (id=" + idStr + ")");
    }

    if (target.empty()) {
        Log::info("No camera-name provided; using SDK default camera");
        return false;
    }

    for (int i = 0; i < list->GetCount(); i++) {
        auto* cam = list->GetItem(i);
        if (!cam) continue;
        const zchar_t* name = cam->GetDeviceName();
        const zchar_t* id = cam->GetDeviceId();
        string nameStr = name ? name : "";
        string idStr = id ? id : "";
        if (!nameStr.empty() && toLowerCopy(nameStr).find(target) != string::npos) {
            SDKError err = videoSettings->SelectCamera(idStr.c_str());
            if (!hasError(err, "select camera")) {
                Log::success("Selected camera: " + nameStr);
                m_cameraSelected = true;
                return true;
            }
            Log::error("Failed to select camera: " + nameStr);
            return false;
        }
    }

    Log::error("No camera matched name substring: " + m_config.cameraName());
    return false;
}

SDKError Zoom::auth() {
    SDKError err{SDKERR_UNINITIALIZE};

    auto id = m_config.clientId();
    auto secret = m_config.clientSecret();

    if (id.empty()) {
        Log::error("Client ID cannot be blank");
        return err;
    }


    if (secret.empty()) {
        Log::error("Client Secret cannot be blank");
        return err;
    }

    auto* authEvent = new AuthServiceEvent(onAuth);
    m_authRetryCount = 0;
    authEvent->setOnAuthenticationReturn([&](AuthResult result) {
        if (result == AUTHRET_SUCCESS) {
            if (onAuth) onAuth();
            return;
        }

        Log::error("authentication failed with AuthResult: " + to_string(result));

        const char* retriesEnv = std::getenv("ZOOM_AUTH_RETRIES");
        int maxRetries = 2; // default: initial auth + 2 retries
        if (retriesEnv && *retriesEnv) {
            maxRetries = std::max(0, std::atoi(retriesEnv));
        }

        // AUTHRET_OVERTIME and unknown (e.g. code 5) are often transient under burst starts.
        const bool retryable = (result == AUTHRET_OVERTIME) || (static_cast<int>(result) == 5);
        if (retryable && m_authRetryCount < maxRetries) {
            m_authRetryCount++;
            const int backoffMs = 400 * m_authRetryCount;
            Log::info("Retrying SDK auth (" + to_string(m_authRetryCount) + "/" + to_string(maxRetries) + ") after " + to_string(backoffMs) + "ms");
            std::this_thread::sleep_for(std::chrono::milliseconds(backoffMs));

            generateJWT(m_config.clientId(), m_config.clientSecret());
            AuthContext retryCtx;
            retryCtx.jwt_token = m_jwt.c_str();
            auto retryErr = m_authService->SDKAuth(retryCtx);
            if (hasError(retryErr, "retry authorize")) {
                std::_Exit(2);
            }
            return;
        }

        std::_Exit(1);
    });

    err = m_authService->SetEvent(authEvent);
    if (hasError(err)) return err;

    generateJWT(m_config.clientId(), m_config.clientSecret());

    // Debug: Log JWT info (first 50 chars only for security)
    Log::info("JWT generated (first 50 chars): " + m_jwt.substr(0, 50) + "...");
    Log::info("Client ID: " + m_config.clientId());
    Log::info("Client Secret length: " + to_string(m_config.clientSecret().length()));

    AuthContext ctx;
    ctx.jwt_token =  m_jwt.c_str();

    return m_authService->SDKAuth(ctx);
}

void Zoom::generateJWT(const string& key, const string& secret) {

    m_iat = std::chrono::system_clock::now();
    m_exp = m_iat + std::chrono::hours{24};

    m_jwt = jwt::create()
            .set_type("JWT")
            .set_issued_at(m_iat)
            .set_expires_at(m_exp)
            .set_payload_claim("appKey", claim(key))
            .set_payload_claim("tokenExp", claim(m_exp))
            .sign(algorithm::hs256{secret});

    // Debug: Log basic JWT info
    Log::info("JWT generated (length: " + to_string(m_jwt.length()) + ")");
    Log::info("Client ID: " + key);
}

SDKError Zoom::join() {
    SDKError err{SDKERR_UNINITIALIZE};

    auto mid = m_config.meetingId();
    auto password = m_config.password();
    auto displayName = m_config.displayName();


    if (mid.empty()) {
        Log::error("Meeting ID cannot be blank");
        return err;
    }

    if (password.empty()) {
        Log::error("Meeting Password cannot be blank");
        return err;
    }

    if (displayName.empty()) {
        Log::error("Display Name cannot be blank");
        return err;
    }

    auto meetingNumber = stoull(mid);
    auto userName = displayName.c_str();
    auto psw = password.c_str();

    // Attempt camera selection (v4l2) before join
    m_cameraSelected = false;
    selectCameraDevice();

    JoinParam joinParam;
    joinParam.userType = ZOOM_SDK_NAMESPACE::SDK_UT_WITHOUT_LOGIN;

    JoinParam4WithoutLogin& param = joinParam.param.withoutloginuserJoin;

    param.meetingNumber = meetingNumber;
    param.userName = userName;
    param.psw = psw;
    param.vanityID = nullptr;
    param.customer_key = nullptr;
    param.webinarToken = nullptr;
    
    bool isAudioOnly = m_config.useRawAudio() && !shouldUseRawVideoSource() && !m_cameraSelected;
    bool iconOnly = m_config.videoIconOnly();
    // For icon-only: join with video OFF, then toggle on/off briefly in onJoin
    param.isVideoOff = iconOnly ? true : false;
    param.isAudioOff = true;
    
    if (iconOnly) {
        Log::info("Icon-only bot: joining with video OFF (will toggle in onJoin)");
    } else if (isAudioOnly) {
        Log::info("Audio-only bot: joining with video ON (will mute in onJoin)");
    } else {
        Log::info("Video bot: joining with video ON");
    }

    if (!m_config.zak().empty()) {
        Log::success("used ZAK token");
        param.userZAK = m_config.zak().c_str();
    }

    if (!m_config.joinToken().empty()) {
        Log::success("used App Privilege token");
        param.app_privilege_token = m_config.joinToken().c_str();
    }

    if (!m_config.onBehalfToken().empty()) {
        Log::success("used On Behalf Token");
        param.onBehalfToken = m_config.onBehalfToken().c_str();
    }

    // Always disable auto-join audio to keep bots muted
    // We'll join VoIP manually if needed for raw audio
    auto* audioSettings = m_settingService->GetAudioSettings();
    if (audioSettings) {
        audioSettings->EnableAutoJoinAudio(false);
    }
    
    if (isAudioOnly || iconOnly) {
        auto* videoSettings = m_settingService->GetVideoSettings();
        if (videoSettings) videoSettings->EnableAutoTurnOffVideoWhenJoinMeeting(false);
    }
    return m_meetingService->Join(joinParam);
}

SDKError Zoom::start() {
    SDKError err;

    StartParam startParam;
    startParam.userType = SDK_UT_NORMALUSER;

    StartParam4NormalUser  normalUser;
    normalUser.vanityID = nullptr;
    normalUser.customer_key = nullptr;
    normalUser.isAudioOff = true;  // Start muted
    normalUser.isVideoOff = m_config.useRawAudio() && m_config.videoInputFile().empty();

    err = m_meetingService->Start(startParam);
    hasError(err, "start meeting");

    return err;
}

SDKError Zoom::leave() {
    if (!m_meetingService) {
        Log::info("Meeting service not available, skipping leave");
        return SDKERR_UNINITIALIZE;
    }

    auto status = m_meetingService->GetMeetingStatus();
    if (status == MEETING_STATUS_IDLE) {
        Log::info("Meeting already idle, skipping leave");
        return SDKERR_WRONG_USAGE;
    }

    Log::info("Leaving meeting...");
    SDKError err = m_meetingService->Leave(LEAVE_MEETING);
    if (!hasError(err)) {
        Log::success("Left meeting successfully");
        // Minimal wait for SDK to process leave - exit quickly
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    } else {
        Log::error("Failed to leave meeting: " + std::to_string(err));
    }
    
    return err;
}

SDKError Zoom::clean() {
    if (m_meetingService)
        DestroyMeetingService(m_meetingService);

    if (m_settingService)
        DestroySettingService(m_settingService);

    if (m_authService)
        DestroyAuthService(m_authService);

    if (m_audioHelper)
        m_audioHelper->unSubscribe();

    if (m_videoHelper)
        m_videoHelper->unSubscribe();

    delete m_renderDelegate;
    return CleanUPSDK();
}

SDKError Zoom::startRawRecording() {
    // Audio subscription is already done in onJoin callback (without permission)
    // Only start actual recording if VIDEO recording is needed
    if (!m_config.useRawVideo()) {
        // Video recording not needed - audio already subscribed in onJoin
        return SDKERR_SUCCESS;
    }
    
    if (m_meetingService->GetMeetingStatus() != ZOOM_SDK_NAMESPACE::MEETING_STATUS_INMEETING) {
        Log::error("You must be in a meeting to start raw recording");
        return SDKERR_WRONG_USAGE;
    }

    auto recCtl = m_meetingService->GetMeetingRecordingController();
    if (!recCtl) {
        Log::error("Failed to get meeting recording controller");
        return SDKERR_INTERNAL_ERROR;
    }

    auto err = recCtl->StartRawRecording();
    if (hasError(err, "start raw recording"))
        return err;

    if (m_config.useRawVideo()) {
        if (!m_renderDelegate) {
            m_renderDelegate = new ZoomSDKRendererDelegate();
            m_videoSource = new ZoomSDKVideoSource();
        }

        err = createRenderer(&m_videoHelper, m_renderDelegate);
        if (hasError(err, "create raw video renderer"))
            return err;

        m_renderDelegate->setDir(m_config.videoDir());
        m_renderDelegate->setFilename(m_config.videoFile());
        
        auto participantCtl = m_meetingService->GetMeetingParticipantsController();
        auto uid = participantCtl->GetParticipantsList()->GetItem(0);

        m_videoHelper->setRawDataResolution(ZoomSDKResolution_720P);
        err = m_videoHelper->subscribe(uid, RAW_DATA_TYPE_VIDEO);
        if (hasError(err, "subscribe to raw video"))
            return err;

        Log::info("writing video raw data to " + m_renderDelegate->dir() + "/" + m_renderDelegate->filename());
    }

    // Send video from file if raw video source is enabled (doesn't require recording)
    if (shouldUseRawVideoSource()) {
        setupVideoSending();
    }


    return SDKERR_SUCCESS;
}

SDKError Zoom::stopRawRecording() {
    auto recCtrl = m_meetingService->GetMeetingRecordingController();
    auto err = recCtrl->StopRawRecording();
    hasError(err, "stop raw recording");

    return err;
}

SDKError Zoom::setupVideoSending() {
    SDKError err{SDKERR_SUCCESS};
    
    if (!shouldUseRawVideoSource()) {
        Log::info("Raw video source not enabled - skipping setupVideoSending");
        return SDKERR_SUCCESS;
    }

    if (m_config.videoInputFile().empty()) {
        return SDKERR_SUCCESS;  // No video to send
    }
    
    if (!m_videoSource) {
        m_videoSource = new ZoomSDKVideoSource();
    }

    auto* videoSourceHelper = GetRawdataVideoSourceHelper();
    if (!videoSourceHelper) {
        Log::error("Failed to get Video Source Helper");
        return SDKERR_UNINITIALIZE;
    }

    err = videoSourceHelper->setExternalVideoSource(m_videoSource);
    if (hasError(err, "set video source"))
        return err;

    // Zoom sample: UnmuteVideo immediately after setExternalVideoSource (no wait)
    auto* videoCtlImmediate = m_meetingService->GetMeetingVideoController();
    if (videoCtlImmediate) {
        videoCtlImmediate->UnmuteVideo();
        Log::info("UnmuteVideo called immediately (Zoom sample flow)");
    }

    auto* videoSettings = m_settingService->GetVideoSettings();
    if (videoSettings) {
        videoSettings->EnableAutoTurnOffVideoWhenJoinMeeting(false);
    }

    // Start sending video from file (will start when onStartSend() is called)
    // The callback will handle starting the video sending when ready
    m_videoSource->startSending(m_config.videoInputFile());
    
    Log::info("Video source configured, waiting for SDK to initialize...");

    // CRITICAL FIX: Wait for video source to be ready before unmuting
    // Desktop app needs video source ready (onStartSend fired) to recognize capability
    auto* videoCtl = m_meetingService->GetMeetingVideoController();
    if (videoCtl) {
        thread([&, videoCtl]() {
            // Wait for video source to be ready (onStartSend callback)
            int maxWait = 10; // Wait up to 5 seconds
            bool isReady = false;
            for (int j = 0; j < maxWait; j++) {
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
                if (m_videoSource && m_videoSource->isReady() && m_videoSource->getSender()) {
                    isReady = true;
                    Log::info("Video source is ready - unmuting to register capability with desktop app");
                    break;
                }
            }
            
            if (isReady) {
                // Now unmute video - desktop app will recognize capability
                SDKError e;
                int unmuteRetries = 0;
                do {
                    Log::info("attempting unmute video (video source ready - registering capability)");
                    e = videoCtl->UnmuteVideo();
                    if (hasError(e, "unmute")) {
                        this_thread::sleep_for(chrono::milliseconds(1000));
                        unmuteRetries++;
                    }
                } while (hasError(e) && unmuteRetries < 10);
                
                if (!hasError(e)) {
                    Log::success("Video unmuted successfully - capability registered with desktop app");
                    
                    // CRITICAL: Desktop app needs video "muted" state to show icon
                    // Strategy: Try immediate mute, then retry after frames are sent
                    // Desktop app recognizes capability when video is unmuted, then muted
                    thread([&, videoCtl]() {
                        // Step 1: Try immediate mute (desktop app might recognize quickly)
                        Log::info("Attempting immediate mute to register capability with desktop app...");
                        SDKError immediateMute = videoCtl->MuteVideo();
                        if (!hasError(immediateMute)) {
                            Log::success("Video muted immediately - desktop app should recognize capability");
                        } else {
                            Log::info("Immediate mute failed (expected) - will retry after frames");
                        }
                        
                        // Step 2: Wait for frames to be sent, then mute again
                        // Desktop app needs time to process video stream
                        std::this_thread::sleep_for(std::chrono::milliseconds(5000));
                        
                        Log::info("Muting video after frames sent - disabled icon should appear in desktop app");
                        int muteRetries = 0;
                        SDKError muteErr;
                        do {
                            muteErr = videoCtl->MuteVideo();
                            if (hasError(muteErr)) {
                                std::this_thread::sleep_for(std::chrono::milliseconds(500));
                                muteRetries++;
                            }
                        } while (hasError(muteErr) && muteRetries < 10);
                        
                        if (!hasError(muteErr)) {
                            Log::success("Video muted - disabled icon should appear in desktop app");
                        } else {
                            Log::error("Failed to mute video after retries - icon may not appear");
                        }
                    }).detach();
                } else {
                    Log::error("Failed to unmute video - desktop app may not recognize video capability");
                }
            } else {
                Log::error("Video source not ready after 5 seconds - capability may not register");
            }
        }).detach();
    }
    
    return SDKERR_SUCCESS;
}

void Zoom::ensureVideoCapabilityForDesktop() {
    // Only for icon-only: register a video source, unmute briefly, then mute
    // If a real camera is available/selected, use it and just toggle on/off
    if (!m_cameraSelected && !m_config.cameraName().empty()) {
        selectCameraDevice();
    }

    auto* videoSettings = m_settingService ? m_settingService->GetVideoSettings() : nullptr;
    if (videoSettings) {
        videoSettings->EnableAutoTurnOffVideoWhenJoinMeeting(false);
    }

    if (!m_cameraSelected) {
        auto* videoSourceHelper = GetRawdataVideoSourceHelper();
        if (!videoSourceHelper) {
            Log::error("Video source helper not available - cannot register video capability");
            return;
        }

        if (!m_videoSource) {
            m_videoSource = new ZoomSDKVideoSource();
        }

        SDKError err = videoSourceHelper->setExternalVideoSource(m_videoSource);
        if (hasError(err, "set video source for icon-only")) {
            return;
        }

        // Start test pattern frames (lightweight) so SDK recognizes capability
        m_videoSource->startSending("TEST_PATTERN");
    }

    auto* videoCtl = m_meetingService->GetMeetingVideoController();
    if (!videoCtl) {
        Log::error("Video controller not available - cannot toggle video");
        return;
    }

    thread([&, videoCtl]() {
        if (m_cameraSelected) {
            // Give camera a moment to warm up
            std::this_thread::sleep_for(std::chrono::milliseconds(800));
        } else {
            int maxWait = 6;
            bool isReady = false;
            for (int j = 0; j < maxWait; j++) {
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
                if (m_videoSource && m_videoSource->isReady() && m_videoSource->getSender()) {
                    isReady = true;
                    break;
                }
            }
            if (!isReady) {
                Log::error("Video source not ready - desktop icon may not appear");
                return;
            }
        }

        // Unmute briefly to register capability
        SDKError unmuteErr = videoCtl->UnmuteVideo();
        if (hasError(unmuteErr, "unmute")) {
            Log::error("Failed to unmute video for icon-only mode");
        } else {
            Log::info("Video unmuted briefly for icon-only registration");
        }

        // Keep unmuted for a short time so desktop/mobile registers capability
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));

        // Mute with spaced retries to avoid SDKERR_TOO_FREQUENT_CALL
        SDKError muteErr;
        int muteRetries = 0;
        do {
            muteErr = videoCtl->MuteVideo();
            if (hasError(muteErr, "mute")) {
                std::this_thread::sleep_for(std::chrono::milliseconds(800));
                muteRetries++;
            }
        } while (hasError(muteErr) && muteRetries < 2);

        if (!hasError(muteErr)) {
            Log::success("Video muted - disabled icon should appear");
        }

        // Keep sending frames after mute so UI retains camera capability
        // (stopping too early can remove the camera icon)
    }).detach();
}

bool Zoom::isMeetingStart() {
    return m_config.isMeetingStart();
}

bool Zoom::hasError(const SDKError e, const string& action) {
    auto isError = e != SDKERR_SUCCESS;

    if(!action.empty()) {
        if (isError) {
            stringstream ss;
            ss << "failed to " << action << " with status " << e;
            Log::error(ss.str());
        } else {
            Log::success(action);
        }
    }
    return isError;
}
