# C++ Code aur Zoom SDK Integration - Complete Explanation

## Overview (Jameel)

Yeh application C++ mein likha gaya hai jo Zoom Meeting SDK ko use karta hai. Main architecture aur flow yeh hai:

## Architecture Flow (Code Ka Flow)

### 1. **Main Entry Point** (`main.cpp`)

```cpp
int main(int argc, char **argv) {
    // 1. Configuration read karo
    // 2. SDK initialize karo
    // 3. Authentication karo
    // 4. Event loop chalao (callbacks ke liye)
}
```

**Kya hota hai:**
- Application start hota hai
- Command line arguments aur config file read hota hai
- SDK initialize hota hai
- Authentication hota hai
- GLib event loop chalta hai (SDK callbacks receive karne ke liye)

### 2. **Configuration Layer** (`Config.h` / `Config.cpp`)

**Purpose:** CLI arguments aur config.toml file se settings read karta hai

**Key Functions:**
- `read()` - CLI arguments aur config file parse karta hai
- `parseUrl()` - Zoom join URL se meeting ID aur password extract karta hai
- Getters - client ID, secret, meeting ID, password, etc.

**Example:**
```cpp
// Config file se yeh read hota hai:
client-id="vdPX1q2bSQKip0X17LqXAw"
client-secret="Te1YdXaBL6IScwdBVlNF0kay75KDMkyz"
join-url="https://us05web.zoom.us/j/5067498331?pwd=..."
```

### 3. **Zoom SDK Wrapper** (`Zoom.h` / `Zoom.cpp`)

Yeh main class hai jo SDK ko wrap karti hai. Singleton pattern use karti hai.

#### **Step 1: Initialize SDK** (`init()`)

```cpp
SDKError Zoom::init() {
    InitParam initParam;
    initParam.strWebDomain = "https://zoom.us";
    initParam.enableLogByDefault = true;
    
    // SDK initialize karo
    InitSDK(initParam);
    
    // Services create karo
    createServices();
}
```

**Kya hota hai:**
- Zoom SDK ko initialize karta hai
- Meeting Service, Setting Service, Auth Service create karta hai
- Event handlers register karta hai

#### **Step 2: Authentication** (`auth()`)

```cpp
SDKError Zoom::auth() {
    // JWT token generate karo
    generateJWT(clientId, clientSecret);
    
    // SDK ko authenticate karo
    AuthContext ctx;
    ctx.jwt_token = m_jwt.c_str();
    m_authService->SDKAuth(ctx);
}
```

**JWT Generation:**
```cpp
void Zoom::generateJWT(const string& key, const string& secret) {
    m_jwt = jwt::create()
        .set_type("JWT")
        .set_issued_at(now)
        .set_expires_at(now + 24 hours)
        .set_payload_claim("appKey", claim(key))
        .sign(algorithm::hs256{secret});
}
```

**Kya hota hai:**
- Client ID aur Secret se JWT token banata hai
- Token ko SDK ko send karta hai
- SDK authenticate karta hai
- Success par callback trigger hota hai

#### **Step 3: Join Meeting** (`join()`)

```cpp
SDKError Zoom::join() {
    JoinParam joinParam;
    joinParam.userType = SDK_UT_WITHOUT_LOGIN;
    
    JoinParam4WithoutLogin& param = joinParam.param.withoutloginuserJoin;
    param.meetingNumber = meetingNumber;
    param.userName = displayName;
    param.psw = password;
    param.isVideoOff = false;
    param.isAudioOff = false;
    
    // Meeting join karo
    m_meetingService->Join(joinParam);
}
```

**Kya hota hai:**
- Meeting ID, password, display name se meeting join karta hai
- SDK meeting connect karta hai
- Status changes par callbacks trigger hote hain

### 4. **Event-Driven Architecture** (Callbacks)

SDK event-driven hai - matlab SDK events trigger karta hai aur hamare callbacks call hote hain.

#### **Authentication Callback** (`AuthServiceEvent`)

```cpp
void AuthServiceEvent::onAuthenticationReturn(AuthResult result) {
    if (result == AUTHRET_SUCCESS) {
        // Authentication successful
        m_onAuth(); // Yeh callback trigger hota hai
    } else {
        // Error handling
    }
}
```

**Flow:**
1. `auth()` call hota hai
2. SDK authenticate karta hai
3. `onAuthenticationReturn()` callback trigger hota hai
4. Success par `onAuth` callback call hota hai
5. `onAuth` callback mein `join()` ya `start()` call hota hai

#### **Meeting Status Callback** (`MeetingServiceEvent`)

```cpp
void MeetingServiceEvent::onMeetingStatusChanged(MeetingStatus status, int iResult) {
    switch (status) {
        case MEETING_STATUS_CONNECTING:
            Log::info("connecting to the meeting");
            break;
        case MEETING_STATUS_INMEETING:
            Log::success("connected");
            if (m_onMeetingJoin) m_onMeetingJoin(); // Meeting join callback
            break;
        case MEETING_STATUS_FAILED:
            Log::error("failed to connect");
            break;
    }
}
```

**Flow:**
1. `join()` call hota hai
2. SDK meeting connect karta hai
3. Status changes: `CONNECTING` → `INMEETING` → `ENDED`
4. Har status change par callback trigger hota hai
5. `INMEETING` status par `onMeetingJoin` callback call hota hai

#### **Meeting Join Callback** (`onJoin`)

```cpp
function<void()> onJoin = [&]() {
    // Meeting join ho gaya
    // Raw recording start kar sakte hain (agar enabled ho)
    if (m_config.useRawRecording()) {
        startRawRecording();
    }
};
```

**Kya hota hai:**
- Meeting successfully join ho jane par yeh callback trigger hota hai
- Isme raw audio/video recording start ho sakti hai

### 5. **Raw Data Recording** (Optional)

Agar config mein raw recording enabled ho:

#### **Audio Recording:**
```cpp
SDKError Zoom::startRawRecording() {
    // Audio helper get karo
    m_audioHelper = GetAudioRawdataHelper();
    
    // Audio delegate create karo
    m_audioSource = new ZoomSDKAudioRawDataDelegate();
    m_audioSource->setDir("out");
    m_audioSource->setFilename("audio.pcm");
    
    // Subscribe karo - ab audio data receive hoga
    m_audioHelper->subscribe(m_audioSource);
}
```

**Flow:**
- SDK audio data send karta hai
- `ZoomSDKAudioRawDataDelegate::onMixedAudioRawDataReceived()` callback trigger hota hai
- Audio data file mein write hota hai

#### **Video Recording:**
```cpp
// Video helper get karo
m_videoHelper = createRenderer(&m_videoHelper, m_renderDelegate);

// Participant se video subscribe karo
m_videoHelper->subscribe(userId, RAW_DATA_TYPE_VIDEO);
```

**Flow:**
- SDK video frames send karta hai
- `ZoomSDKRendererDelegate` callbacks trigger hote hain
- Video frames file mein write hote hain

### 6. **Event Loop** (GLib)

```cpp
int main() {
    // Event loop create karo
    GMainLoop* eventLoop = g_main_loop_new(NULL, FALSE);
    
    // Timeout add karo (SDK callbacks ke liye)
    g_timeout_add(100, onTimeout, eventLoop);
    
    // Loop chalao - yeh SDK callbacks receive karta hai
    g_main_loop_run(eventLoop);
}
```

**Kya hota hai:**
- GLib event loop SDK callbacks receive karne ke liye chalta hai
- SDK internally events trigger karta hai
- Hamare registered callbacks call hote hain

## Complete Flow Diagram

```
1. main() starts
   ↓
2. Zoom::config() - Read CLI/config
   ↓
3. Zoom::init() - Initialize SDK
   ├─ InitSDK()
   └─ createServices()
      ├─ CreateMeetingService()
      ├─ CreateSettingService()
      └─ CreateAuthService()
   ↓
4. Zoom::auth() - Authenticate
   ├─ generateJWT()
   └─ SDKAuth()
      ↓
   [SDK Callback] AuthServiceEvent::onAuthenticationReturn()
      ↓
   [Success] onAuth callback
      ↓
5. Zoom::join() - Join meeting
   └─ MeetingService::Join()
      ↓
   [SDK Callback] MeetingServiceEvent::onMeetingStatusChanged()
      ├─ MEETING_STATUS_CONNECTING
      ├─ MEETING_STATUS_INMEETING → onMeetingJoin callback
      │   └─ startRawRecording() (if enabled)
      └─ MEETING_STATUS_ENDED
   ↓
6. GLib Event Loop - Keeps running for callbacks
   ↓
7. onExit() - Cleanup when app exits
```

## Key SDK Interfaces

### **IMeetingService**
- `Join()` - Meeting join karna
- `Start()` - Meeting start karna
- `Leave()` - Meeting leave karna
- `GetMeetingStatus()` - Current status check karna
- `GetMeetingAudioController()` - Audio control
- `GetMeetingVideoController()` - Video control

### **IAuthService**
- `SDKAuth()` - SDK ko authenticate karna
- JWT token se authentication

### **ISettingService**
- `GetAudioSettings()` - Audio settings
- `GetVideoSettings()` - Video settings

### **Raw Data Helpers**
- `GetAudioRawdataHelper()` - Audio raw data receive karna
- `createRenderer()` - Video raw data receive karna

## Error Handling

```cpp
bool Zoom::hasError(SDKError e, const string& action) {
    if (e != SDKERR_SUCCESS) {
        Log::error("failed to " + action + " with status " + e);
        return true;
    }
    Log::success(action);
    return false;
}
```

Har SDK call ke baad error check hota hai aur appropriate logging hoti hai.

## Summary (Khulasa)

1. **Configuration** - CLI/config se settings read
2. **Initialization** - SDK ko initialize karo
3. **Authentication** - JWT token se authenticate karo
4. **Join Meeting** - Meeting ID/password se join karo
5. **Event Callbacks** - SDK events par callbacks trigger hote hain
6. **Raw Data** - Optional audio/video recording
7. **Event Loop** - GLib loop callbacks receive karta hai

Yeh sab **asynchronous** hai - SDK operations background mein hote hain aur callbacks se results milte hain.

