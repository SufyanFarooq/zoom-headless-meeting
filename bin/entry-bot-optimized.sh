#!/usr/bin/env bash

# Optimized entry script for multiple bots
# Reduces CPU and memory usage

# directory for CMake output
BUILD=build

# directory for application output
mkdir -p out

# Disable unnecessary logging
export QT_LOGGING_RULES="*.debug=false;*.warning=false;*.info=false;*.critical=false"
export QT_QPA_PLATFORM=offscreen

setup-pulseaudio() {
  # Enable dbus
  if [[  ! -d /var/run/dbus ]]; then
    mkdir -p /var/run/dbus
    dbus-uuidgen > /var/lib/dbus/machine-id
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address > /dev/null 2>&1
  fi

  usermod -G pulse-access,audio root > /dev/null 2>&1

  # Cleanup to be "stateless" on startup
  rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse/ 2>/dev/null
  mkdir -p ~/.config/pulse/ && cp -r /etc/pulse/* "$_" 2>/dev/null

  # Start pulseaudio with minimal configuration
  pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --log-level=0 > /dev/null 2>&1

  # Create a virtual speaker output (minimal)
  pactl load-module module-null-sink sink_name=SpeakerOutput > /dev/null 2>&1
  pactl set-default-sink SpeakerOutput > /dev/null 2>&1
  pactl set-default-source SpeakerOutput.monitor > /dev/null 2>&1

  # Make config file
  echo -e "[General]\nsystem.audio.type=default" > ~/.config/zoomus.conf 2>/dev/null
}

build() {
  # Log build start
  echo "Starting build process..." >&2
  
  # Check if build directory exists but is incomplete (no executable)
  if [[ -d "$BUILD" ]] && [[ ! -f "$BUILD/zoomsdk" ]]; then
    echo "Build directory exists but executable missing - checking cache..." >&2
    # Check if CMakeCache.txt exists and verify if it's corrupted
    if [[ -f "$BUILD/CMakeCache.txt" ]]; then
      # Try to verify cache by running cmake
      if ! cmake -B "$BUILD" -S . --preset debug > /dev/null 2>&1; then
        echo "CMake cache corrupted - cleaning build directory..." >&2
        rm -rf "$BUILD"/* 2>/dev/null
      else
        echo "CMake cache is valid, but executable missing - will rebuild..." >&2
        # Cache is valid but executable missing, just remove cache to force rebuild
        rm -f "$BUILD/CMakeCache.txt" 2>/dev/null
      fi
    else
      echo "No CMake cache found - will configure fresh..." >&2
    fi
  fi
  
  # Only build if build directory doesn't exist or is empty
  if [[ ! -d "$BUILD" ]] || [[ -z "$(ls -A $BUILD 2>/dev/null)" ]] || [[ ! -f "$BUILD/CMakeCache.txt" ]]; then
    echo "Running cmake configuration..." >&2
    cmake -B "$BUILD" -S . --preset debug 2>&1 | tee /tmp/meeting-sdk-linux-sample/out/cmake.log || {
      echo "ERROR: CMake configuration failed" >&2
      cat /tmp/meeting-sdk-linux-sample/out/cmake.log >&2
      exit 1
    }
  else
    echo "Build directory exists, skipping cmake..." >&2
  fi

  # Rename the shared library (only once)
  LIB="lib/zoomsdk/libmeetingsdk.so"
  if [[ ! -f "${LIB}.1" ]]; then
    echo "Copying shared library..." >&2
    cp "$LIB"{,.1} 2>/dev/null || echo "Warning: Could not copy library" >&2
  fi

  # Set up and start pulseaudio (minimal)
  echo "Setting up pulseaudio..." >&2
  setup-pulseaudio

  # Build only if needed (check if executable exists)
  if [[ ! -f "$BUILD/zoomsdk" ]]; then
    echo "Building application..." >&2
    cmake --build "$BUILD" 2>&1 | tee /tmp/meeting-sdk-linux-sample/out/build.log || {
      echo "ERROR: Build failed" >&2
      cat /tmp/meeting-sdk-linux-sample/out/build.log >&2
      exit 1
    }
  else
    echo "Executable exists, skipping build..." >&2
  fi
  
  # Verify executable exists
  if [[ ! -f "$BUILD/zoomsdk" ]]; then
    echo "ERROR: Build failed - executable not found at $BUILD/zoomsdk" >&2
    echo "Build directory contents:" >&2
    ls -la "$BUILD" >&2 || echo "Build directory does not exist" >&2
    exit 1
  fi
  
  echo "Build successful - executable found at $BUILD/zoomsdk" >&2
}

run() {
    # Disable most logging but keep errors visible
    export QT_LOGGING_RULES="*.debug=false;*.warning=false;*.info=false"
    export QT_QPA_PLATFORM=offscreen
    
    # Reduce glib logging
    export G_MESSAGES_DEBUG=""
    
    # Run - keep stderr for errors (redirect to file for debugging)
    # Log errors to file for debugging
    ERROR_LOG="/tmp/meeting-sdk-linux-sample/out/error.log"
    mkdir -p "$(dirname "$ERROR_LOG")"
    
    # Check if executable exists before running
    if [[ ! -f "$BUILD/zoomsdk" ]]; then
        echo "ERROR: Executable not found at $BUILD/zoomsdk" >&2
        echo "ERROR: Executable not found at $BUILD/zoomsdk" >> "$ERROR_LOG"
        exit 1
    fi
    
    # Run application - capture errors (temporarily enable stderr to see errors)
    ./"$BUILD"/zoomsdk "$@" 2>&1 | tee -a "$ERROR_LOG" || {
        EXIT_CODE=$?
        echo "Application exited with code $EXIT_CODE" >> "$ERROR_LOG"
        exit $EXIT_CODE
    }
}

# Build only if needed, then run
build && run "$@";

exit $?

