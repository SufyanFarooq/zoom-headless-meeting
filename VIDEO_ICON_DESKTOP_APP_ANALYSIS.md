# Video Icon in Zoom Desktop App - Fix & Analysis

## Fix Applied (Continuous Frames)

**Root cause:** Desktop App only shows video icon when raw video sender is **active** and **continuous** frames are sent. Stopping the sender (MuteVideo) or sending few frames makes it treat participant as audio-only.

**Solution:**
1. Pass **both** `RawAudio` and `RawVideo` for audio-only bots (CLI11 allow 2 subcommands)
2. Send **continuous** black frames (~15 FPS) for entire meeting – never call `MuteVideo()`
3. Call `UnmuteVideo()` to enable video capability
4. Join with `isVideoOff=false`

**Expected:** Video icon visible (enabled or disabled) in Desktop App. Web client unchanged.

---

## Analysis (Legacy)

## Summary
The Arjun bot's **disabled video icon** shows correctly in **Zoom Web** but **not in Zoom Desktop App**. This appears to be a Zoom desktop client limitation, not a bug in our SDK usage.

## What We've Verified (From Container Logs)

✅ **SDK Flow is Correct:**
- Join with `isVideoOff=false` (video ON)
- Register external video source via `setExternalVideoSource`
- Unmute video to trigger `onStartSend`
- Send 150 black frames (10 seconds) at 15 FPS
- Mute video after frames complete
- Mute succeeds: "Final video mute successful"

✅ **Web Client Works:** Shows disabled video icon (red strikethrough camera)
✅ **Backend:** Zoom servers receive correct participant state (video capability + muted)

## Root Cause Hypothesis

Based on [Zoom Meeting SDK for Linux documentation](https://developers.zoom.us/docs/meeting-sdk/linux/):

1. **Raw Data vs Camera Video:** We use `GetRawdataVideoSourceHelper()` and `setExternalVideoSource()` - this injects **custom/raw video data**, not a system camera. The Zoom desktop app may render participants using raw data differently than web.

2. **Desktop App Platform Differences:** [Zoom Community](https://community.zoom.com/t5/Zoom-Meetings/49-participant-view-in-linux-desktop-client/m-p/222959) reports that the Linux desktop client has feature differences vs Windows/macOS. Similar differences may exist for how participant video icons are displayed.

3. **SDK Participant Type:** We join with `SDK_UT_WITHOUT_LOGIN` + ZAK token (Profile Pic Member). The desktop app might handle this participant type's video state differently in its UI.

## Recommendation

**Report to Zoom Support / Developer Forum:**
- Product: Zoom Meeting SDK for Linux
- Issue: Participant video icon (disabled state) does not appear in Zoom Desktop App for participants using `setExternalVideoSource` (raw data), while Zoom Web client displays it correctly
- Include: SDK version, join params (`isVideoOff=false`, ZAK token), logs showing 150 black frames sent + successful mute

**Workaround:** Accept that the desktop app may not show the icon. Web client and backend state are correct. For users viewing from desktop, they will see the participant (Arjun) with mic icon only.

## References
- [Zoom Meeting SDK for Linux](https://developers.zoom.us/docs/meeting-sdk/linux/)
- [Get Started - MSDK Linux](https://developers.zoom.us/blog/get-started-with-msdk-for-linux/)
- [Raw Data API - zoom_rawdata_api.h](https://marketplacefront.zoom.us/sdk/meeting/linux/zoom__rawdata__api_8h.html)
