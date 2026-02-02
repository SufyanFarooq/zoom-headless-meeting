#!/usr/bin/env bash
# Run N bots in one container for faster scaling (e.g. 10 bots = 1 container instead of 10)
# Requires: BOT_CONFIG_FILE (path to file with lines: display_name|zak_token)
#           JOIN_URL, BOT_COUNT

set -e
BUILD=build
cd /tmp/meeting-sdk-linux-sample || cd .

# Setup Xvfb for multiple displays (each bot needs own display to avoid X11 conflicts)
setup_xvfb() {
    for i in $(seq 0 $((BOT_COUNT - 1))); do
        DISPLAY_NUM=$((99 + i))
        if [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ]; then
            Xvfb :${DISPLAY_NUM} -screen 0 640x480x24 -ac +extension GLX +render -noreset &
            sleep 0.3
        fi
    done
    sleep 1
}

# Setup pulseaudio (shared)
setup_pulseaudio() {
    export DISPLAY=:99
    mkdir -p /var/run/dbus /root/.config/pulse 2>/dev/null || true
    dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
    pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --log-level=0 2>/dev/null || true
    sleep 1
    pactl load-module module-null-sink sink_name=SpeakerOutput 2>/dev/null || true
    pactl set-default-sink SpeakerOutput 2>/dev/null || true
}

# Single bot launcher
run_bot() {
    local BOT_ID=$1
    local DISPLAY_NUM=$2
    local DISPLAY_NAME=$3
    local ZAK_TOKEN=$4
    
    export DISPLAY=:${DISPLAY_NUM}
    export QT_LOGGING_RULES="*.debug=false;*.warning=false;*.info=false"
    export QT_QPA_PLATFORM=offscreen
    
    if [ -n "$ZAK_TOKEN" ] && [ "$ZAK_TOKEN" != "none" ]; then
        ./"$BUILD"/zoomsdk --join-url "$JOIN_URL" --display-name "$DISPLAY_NAME" --config config.toml --zak "$ZAK_TOKEN" RawAudio --file dev-null.pcm --dir /dev
    else
        ./"$BUILD"/zoomsdk --join-url "$JOIN_URL" --display-name "$DISPLAY_NAME" --config config.toml RawAudio --file dev-null.pcm --dir /dev
    fi
}

# Main
BOT_COUNT=${BOT_COUNT:-1}
BOT_CONFIG_FILE=${BOT_CONFIG_FILE:-}

if [ "$BOT_COUNT" -le 1 ] || [ ! -f "$BOT_CONFIG_FILE" ]; then
    echo "Usage: BOT_COUNT=N BOT_CONFIG_FILE=/path/to/config JOIN_URL=... $0"
    echo "Config format: one line per bot: display_name|zak_token (use 'none' for no ZAK)"
    exit 1
fi

# Build once (shared - all bots in container use same binary)
if [ ! -f "$BUILD/zoomsdk" ]; then
    echo "Building zoomsdk (first run in this container)..."
    mkdir -p /tmp/build-logs 2>/dev/null || true
    cmake -B "$BUILD" -S . --preset debug 2>/dev/null || cmake -B "$BUILD" -S . -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=20
    cmake --build "$BUILD" -j2
fi

setup_xvfb
setup_pulseaudio

echo "Starting $BOT_COUNT bots in parallel..."
BOT_ID=0
PIDS=()
while IFS='|' read -r DISPLAY_NAME ZAK_TOKEN; do
    [ -z "$DISPLAY_NAME" ] && continue
    DISPLAY_NUM=$((99 + BOT_ID))
    run_bot "$BOT_ID" "$DISPLAY_NUM" "$DISPLAY_NAME" "${ZAK_TOKEN:-none}" &
    PIDS+=($!)
    BOT_ID=$((BOT_ID + 1))
    [ $BOT_ID -ge $BOT_COUNT ] && break
done < "$BOT_CONFIG_FILE"

# Wait for all
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done
