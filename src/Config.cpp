#include "Config.h"

Config::Config() :
        m_app(m_name, "zoomsdk"),
        m_rawRecordAudioCmd(m_app.add_subcommand("RawAudio", "Enable Audio Raw Recording")),
        m_rawRecordVideoCmd(m_app.add_subcommand("RawVideo", "Enable Video Raw Recording"))
    {
    m_app.set_config("--config", "config.toml");
    m_app.require_subcommand(0, 2);  // Allow both RawAudio + RawVideo for audio-only with video icon

    m_app.add_option("-m, --meeting-id", m_meetingId,"Meeting ID of the meeting");
    m_app.add_option("-p, --password", m_password,"Password of the meeting");
    m_app.add_option("-n, --display-name", m_displayName,"Display Name for the meeting")->capture_default_str();
    
    m_app.add_option("--profile-picture", m_profilePicturePath, "Path to profile picture image file (JPG/PNG)");

    m_app.add_option("-z,--zak", m_zak, "ZAK Token to join the meeting");

    m_app.add_option("--host", m_zoomHost, "Host Domain for the Zoom Meeting")->capture_default_str();
    m_app.add_option("-u, --join-url", m_joinUrl, "Join or Start a Meeting URL");
    m_app.add_option("-t, --join-token", m_joinToken, "Join the meeting with App Privilege using a token");
    m_app.add_option("-b, --on-behalf", m_onBehalfToken, "Join the meeting on behalf of a user using a token");


    // Client ID/Secret should come from config.toml by default
    // Command line args are optional and only used if provided
    m_app.add_option("--client-id", m_clientId, "Zoom Meeting Client ID");
    m_app.add_option("--client-secret", m_clientSecret, "Zoom Meeting Client Secret");

    m_app.add_flag("-s, --start", m_isMeetingStart, "Start a Zoom Meeting");

    m_rawRecordAudioCmd->add_option("-f, --file", m_audioFile, "Output PCM audio file")->required();
    m_rawRecordAudioCmd->add_option("-d, --dir", m_audioDir, "Audio Output Directory");
    m_rawRecordAudioCmd->add_flag("-s, --separate-participants", m_separateParticipantAudio, "Output to separate PCM files for each participant");
    m_rawRecordAudioCmd->add_flag("-t, --transcribe", m_transcribe, "Transcribe audio to text");

    m_rawRecordVideoCmd->add_option("-f, --file", m_videoFile, "Output YUV video file");
    m_rawRecordVideoCmd->add_option("-d, --dir", m_videoDir, "Video Output Directory");
    m_rawRecordVideoCmd->add_option("--input", m_videoInputFile, "Input video file to send (MP4, H.264)");

    m_app.add_option("--camera-name", m_cameraName, "Camera name substring to select (v4l2)");
    m_app.add_option("--camera-mode", m_cameraMode, "Camera mode: auto|v4l2|raw")
        ->capture_default_str()
        ->check(CLI::IsMember({"auto", "v4l2", "raw"}));
    m_app.add_flag("--video-icon-only", m_videoIconOnly, "Register video capability to show disabled camera icon");
}

int Config::read(int ac, char **av) {
    try {
        m_app.parse(ac, av);
    } catch( const CLI::CallForHelp &e ){
        exit(m_app.exit(e));
    } catch (const CLI::ParseError& err) {
        return m_app.exit(err);
    } 

    if (!m_joinUrl.empty())
        parseUrl(m_joinUrl);

    // Debug: Check what was parsed BEFORE clearing
    if (m_rawRecordAudioCmd->parsed()) {
        cerr << "RawAudio subcommand activated" << endl;
        cerr << "Video input file BEFORE clearing: " << (m_videoInputFile.empty() ? "EMPTY" : m_videoInputFile) << endl;
    }
    if (m_rawRecordVideoCmd->parsed()) {
        cerr << "RawVideo subcommand activated" << endl;
        cerr << "Video input file: " << (m_videoInputFile.empty() ? "EMPTY" : m_videoInputFile) << endl;
    } else {
        cerr << "RawVideo subcommand NOT activated" << endl;
    }

    // If RawAudio only (no RawVideo), clear video input - audio-only without video icon path
    // If both RawAudio + RawVideo: enable icon-only mode (test pattern), no explicit input required
    if (m_rawRecordAudioCmd->parsed() && !m_rawRecordVideoCmd->parsed()) {
        cerr << "Clearing video input file for audio-only bot (no RawVideo)..." << endl;
        m_videoInputFile.clear();
        m_videoFile.clear();
    } else if (m_rawRecordAudioCmd->parsed() && m_rawRecordVideoCmd->parsed() && m_videoInputFile.empty()) {
        cerr << "Audio+Video icon mode: RawAudio + RawVideo (test pattern for Desktop icon)" << endl;
        m_videoIconOnly = true;
    }

   return 0;
}

// Your updated Config::parseUrl function
bool Config::parseUrl(const string& join_url) {
    auto url = UrlParser::parse(join_url);
    
    if (!url.valid) {
        cerr << "unable to parse join URL" << endl;
        return false;
    }
    
    string token, lastRoute;
    istringstream ss(url.path);
    
    while (getline(ss, token, '/')) {
        if (token.empty()) continue;
        
        m_isMeetingStart = token == "s";
        
        if (lastRoute == "j" || lastRoute == "s") {
            m_meetingId = token;
            break;
        }
        
        lastRoute = token;
    }
    
    if (m_meetingId.empty()) 
        return false;
    
    auto pwdIt = url.queryParams.find("pwd");
    if (pwdIt == url.queryParams.end()) 
        return false;
    
    m_password = pwdIt->second;
    
    return true;
}
const string& Config::clientId() const {
    return m_clientId;
}

const string& Config::clientSecret() const {
    return m_clientSecret;
}

const string &Config::zak() const
{
    return m_zak;
}

bool Config::useRawRecording() const {
    return useRawAudio() || useRawVideo();
}

bool Config::useRawAudio() const {
    return !m_audioFile.empty() || m_separateParticipantAudio || m_transcribe;
}

bool Config::useRawVideo() const {
    return !m_videoFile.empty();
}

bool Config::transcribe() const
{
    return m_transcribe;
}

const string& Config::audioDir() const {
    return m_audioDir;
}

const string& Config::audioFile() const {
        return m_audioFile;

}

const string& Config::videoDir() const {
    return m_videoDir;
}
const string& Config::videoFile() const {
    return m_videoFile;
}

const string& Config::videoInputFile() const {
    return m_videoInputFile;
}

bool Config::isVideoIconOnlyMode() const {
    return m_videoIconOnly || m_videoInputFile == "black";
}

const string& Config::cameraName() const {
    return m_cameraName;
}

const string& Config::cameraMode() const {
    return m_cameraMode;
}

string Config::resolvedCameraMode() const {
    if (m_cameraMode == "raw" || m_cameraMode == "v4l2") return m_cameraMode;
    if (!m_videoInputFile.empty()) return "raw";
    if (!m_cameraName.empty()) return "v4l2";
    return "auto";
}

bool Config::videoIconOnly() const {
    return m_videoIconOnly;
}

const string& Config::profilePicturePath() const {
    return m_profilePicturePath;
}

bool Config::separateParticipantAudio() const {
    return m_separateParticipantAudio;
}

bool Config::isMeetingStart() const {
    return m_isMeetingStart;
}

const string& Config::joinToken() const {
    return m_joinToken;
}

const string &Config::onBehalfToken() const
{
    return m_onBehalfToken;
}

const string& Config::meetingId() const {
    return m_meetingId;
}

const string& Config::password() const {
    return m_password;
}

const string& Config::displayName() const {
    return m_displayName;
}

const string& Config::zoomHost() const {
    return m_zoomHost;
}
