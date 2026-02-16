#!/usr/bin/env bash

set -euo pipefail

RUNTIME_ROOT="/opt/zoomsdk-runtime"
RUNTIME_BIN="${RUNTIME_ROOT}/zoomsdk"
LIB_ROOT="${RUNTIME_ROOT}/lib"

export QT_LOGGING_RULES="${QT_LOGGING_RULES:-*.debug=false;*.warning=false;*.info=false;*.critical=false}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
export G_MESSAGES_DEBUG="${G_MESSAGES_DEBUG:-}"
export LD_LIBRARY_PATH="${LIB_ROOT}/zoomsdk:${LIB_ROOT}/zoomsdk/qt_libs:/usr/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib:${LD_LIBRARY_PATH:-}"

setup_xvfb() {
  export DISPLAY="${DISPLAY:-:99}"
  if [ ! -S "/tmp/.X11-unix/X99" ]; then
    Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    for _ in $(seq 1 20); do
      [ -S "/tmp/.X11-unix/X99" ] && break
      sleep 0.1
    done
  fi
}

setup_pulseaudio() {
  if [[ ! -d /var/run/dbus ]]; then
    mkdir -p /var/run/dbus /var/lib/dbus
    dbus-uuidgen > /var/lib/dbus/machine-id
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address >/dev/null 2>&1 || true
  fi

  usermod -G pulse-access,audio root >/dev/null 2>&1 || true
  rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse/ 2>/dev/null || true
  mkdir -p ~/.config/pulse/ && cp -r /etc/pulse/* "$_" 2>/dev/null || true

  modprobe snd-dummy >/dev/null 2>&1 || true
  pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --log-level=0 >/dev/null 2>&1 || true

  for _ in $(seq 1 20); do
    pactl info >/dev/null 2>&1 && break
    sleep 0.1
  done

  pactl load-module module-null-sink sink_name=SpeakerOutput >/dev/null 2>&1 || true
  pactl set-default-sink SpeakerOutput >/dev/null 2>&1 || true
  pactl load-module module-null-source source_name=DummyMic >/dev/null 2>&1 || true
  pactl set-default-source DummyMic >/dev/null 2>&1 || true

  mkdir -p ~/.config
  cat > ~/.asoundrc << 'ASOUND'
pcm.!default { type pulse }
ctl.!default { type pulse }
ASOUND
}

if [[ "${1:-}" == "--warmup-only" ]]; then
  setup_xvfb
  setup_pulseaudio
  echo "Warm bot container ready"
  while true; do sleep 3600; done
fi

setup_xvfb
setup_pulseaudio

if [ ! -x "$RUNTIME_BIN" ]; then
  echo "❌ zoomsdk binary not found at ${RUNTIME_BIN}" >&2
  exit 1
fi

if [ "${ENTRY_DEBUG_ARGS:-false}" = "true" ] && echo "$*" | grep -q "\--zak"; then
  echo "🔍 DEBUG: --zak argument detected" >&2
fi

if [ -n "${TIMEOUT_SECONDS:-}" ] && [ "${TIMEOUT_SECONDS}" -gt 0 ] 2>/dev/null; then
  echo "⏱  Bot will leave meeting after ${TIMEOUT_SECONDS}s" >&2
  exec timeout "${TIMEOUT_SECONDS}" "$RUNTIME_BIN" "$@"
fi

exec "$RUNTIME_BIN" "$@"
