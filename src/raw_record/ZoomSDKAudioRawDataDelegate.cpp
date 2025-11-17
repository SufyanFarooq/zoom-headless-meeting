#include "ZoomSDKAudioRawDataDelegate.h"


ZoomSDKAudioRawDataDelegate::ZoomSDKAudioRawDataDelegate(bool useMixedAudio = true, bool transcribe = false) : m_useMixedAudio(useMixedAudio), m_transcribe(transcribe){}

void ZoomSDKAudioRawDataDelegate::onMixedAudioRawDataReceived(AudioRawData *data) {
    if (!m_useMixedAudio) return;
    
    // If this is dummy recording (for mic icon), discard data immediately
    // Check filename or full path for dev-null.pcm
    if (m_filename == "dev-null.pcm" || 
        m_filename == "/dev/null" ||
        (m_dir == "/dev" && m_filename.find("null") != string::npos)) {
        // Discard audio data - we only need recording enabled for mic icon
        return;
    }

    // write to socket
    if (m_transcribe) {
        server.writeBuf(data->GetBuffer(), data->GetBufferLen());
        return;
    }

    // or write to file
    if (m_dir.empty())
        return Log::error("Output Directory cannot be blank");


    if (m_filename.empty())
        m_filename = "test.pcm";


    stringstream path;
    // Handle absolute paths - don't prepend directory
    if (m_filename[0] == '/') {
        path << m_filename;
    } else {
        path << m_dir << "/" << m_filename;
    }

    writeToFile(path.str(), data);
}



void ZoomSDKAudioRawDataDelegate::onOneWayAudioRawDataReceived(AudioRawData* data, uint32_t node_id) {
    if (m_useMixedAudio) return;
    
    // If this is dummy recording (for mic icon), discard data
    if (m_filename == "dev-null.pcm" || 
        (m_dir == "/dev" && m_filename.find("null") != string::npos)) {
        // Discard audio data - we only need recording enabled for mic icon
        return;
    }

    stringstream path;
    path << m_dir << "/node-" << node_id << ".pcm";
    writeToFile(path.str(), data);
}

void ZoomSDKAudioRawDataDelegate::onShareAudioRawDataReceived(AudioRawData* data, unsigned int user_id) {
    stringstream ss;
    ss << "Shared Audio Raw data: " << data->GetBufferLen() / 10 << "k at " << data->GetSampleRate() << "Hz";
    Log::info(ss.str());
}


void ZoomSDKAudioRawDataDelegate::writeToFile(const string &path, AudioRawData *data)
{
    static std::ofstream file;
	file.open(path, std::ios::out | std::ios::binary | std::ios::app);

	if (!file.is_open())
        return Log::error("failed to open audio file path: " + path);
	
    file.write(data->GetBuffer(), data->GetBufferLen());

    file.close();
	file.flush();

    stringstream ss;
    ss << "Writing " << data->GetBufferLen() << "b to " << path << " at " << data->GetSampleRate() << "Hz";

    //Log::info(ss.str());
}

string ZoomSDKAudioRawDataDelegate::dir() const 
{
    return m_dir;
}
void ZoomSDKAudioRawDataDelegate::setDir(const string &dir)
{
    m_dir = dir;
}

string ZoomSDKAudioRawDataDelegate::filename() const 
{
    return m_filename;
}
void ZoomSDKAudioRawDataDelegate::setFilename(const string &filename)
{
    m_filename = filename;
}
