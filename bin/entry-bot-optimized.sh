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


  # Load ALSA dummy module for virtual audio device
  # This ensures Zoom SDK can detect an audio device
  # Note: modprobe might not work in containers without --privileged
  modprobe snd-dummy > /dev/null 2>&1 || true
  
  # Check if module loaded (using /proc/modules if lsmod not available)
  if command -v lsmod > /dev/null 2>&1; then
    if lsmod | grep -q snd_dummy; then
      echo "ALSA dummy device loaded successfully" > /dev/null 2>&1
    fi
  elif [ -f /proc/modules ]; then
    if grep -q snd_dummy /proc/modules; then
      echo "ALSA dummy device loaded successfully" > /dev/null 2>&1
    fi
  fi

  # Start pulseaudio with minimal configuration
  pulseaudio -D --exit-idle-time=-1 --system --disallow-exit --log-level=0 > /dev/null 2>&1

  # Wait for pulseaudio to start
  sleep 1

  # Create a virtual speaker output (minimal)
  pactl load-module module-null-sink sink_name=SpeakerOutput > /dev/null 2>&1
  pactl set-default-sink SpeakerOutput > /dev/null 2>&1
  pactl set-default-source SpeakerOutput.monitor > /dev/null 2>&1

  # Also create a dummy source for microphone
  pactl load-module module-null-source source_name=DummyMic > /dev/null 2>&1
  pactl set-default-source DummyMic > /dev/null 2>&1 || true

  # Verify audio devices are available
  if command -v pactl > /dev/null 2>&1; then
    # Check if default sink exists
    if ! pactl list short sinks | grep -q SpeakerOutput; then
      echo "Warning: PulseAudio sink not created properly" > /dev/null 2>&1
    fi
  fi

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
    # Ensure log directory exists before writing to it
    mkdir -p /tmp/meeting-sdk-linux-sample/out
    
    # Try preset first, but if it fails due to vcpkg, try without preset
    # Use PIPESTATUS to capture cmake's exit code, not tee's
    cmake -B "$BUILD" -S . --preset debug 2>&1 | tee /tmp/meeting-sdk-linux-sample/out/cmake.log
    CMAKE_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $CMAKE_EXIT_CODE -ne 0 ]; then
      echo "CMake with preset failed, trying without vcpkg toolchain..." >&2
      # Configure without vcpkg toolchain (system packages only)
      cmake -B "$BUILD" -S . \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        2>&1 | tee /tmp/meeting-sdk-linux-sample/out/cmake.log
      CMAKE_EXIT_CODE=${PIPESTATUS[0]}
      
      if [ $CMAKE_EXIT_CODE -ne 0 ]; then
        echo "ERROR: CMake configuration failed" >&2
        cat /tmp/meeting-sdk-linux-sample/out/cmake.log >&2
        exit 1
      fi
    fi
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

  # Check if source files changed (force rebuild if Zoom.h or Zoom.cpp changed)
  # This ensures JoinVoip changes are compiled
  NEED_REBUILD=false
  if [[ ! -f "$BUILD/zoomsdk" ]]; then
    NEED_REBUILD=true
  elif [[ "src/Zoom.h" -nt "$BUILD/zoomsdk" ]] || [[ "src/Zoom.cpp" -nt "$BUILD/zoomsdk" ]]; then
    echo "Source files changed, rebuilding..." >&2
    NEED_REBUILD=true
  fi
  
  # Build only if needed
  if [[ "$NEED_REBUILD" == "true" ]]; then
    echo "Building application..." >&2
    cmake --build "$BUILD" 2>&1 | tee /tmp/meeting-sdk-linux-sample/out/build.log || {
      echo "ERROR: Build failed" >&2
      cat /tmp/meeting-sdk-linux-sample/out/build.log >&2
      exit 1
    }
  else
    echo "Executable exists and up to date, skipping build..." >&2
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
    
    # Set library path for OpenCV and other libraries
    # Include all possible OpenCV library locations
    export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/lib:/usr/lib:${LD_LIBRARY_PATH}
    
    # Find and add OpenCV library path - check multiple locations
    OPENCV_LIB_DIR=""
    
    # Method 1: Find any libopencv_*.so* file and get its directory
    for search_dir in /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib; do
        if [ -d "$search_dir" ]; then
            OPENCV_LIB=$(find "$search_dir" -name "libopencv_*.so*" -type f 2>/dev/null | head -1)
            if [ -n "$OPENCV_LIB" ]; then
                OPENCV_LIB_DIR=$(dirname "$OPENCV_LIB")
                break
            fi
        fi
    done
    
    # Method 2: Check for specific version (4.06 or 4.5 or 4.8)
    if [ -z "$OPENCV_LIB_DIR" ]; then
        for version in 406 4.5 4.8 4.6 4.0; do
            for search_dir in /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib; do
                # Check for both version formats: .406 and .4.5
                if [ -f "$search_dir/libopencv_videoio.so.$version" ] || [ -f "$search_dir/libopencv_core.so.$version" ]; then
                    OPENCV_LIB_DIR="$search_dir"
                    break 2
                fi
            done
        done
    fi
    
    # Method 3: Use pkg-config to find OpenCV libdir
    if [ -z "$OPENCV_LIB_DIR" ] && command -v pkg-config > /dev/null 2>&1; then
        OPENCV_LIB_DIR=$(pkg-config --variable=libdir opencv4 2>/dev/null || pkg-config --variable=libdir opencv 2>/dev/null)
    fi
    
    # Add found directory to LD_LIBRARY_PATH
    if [ -n "$OPENCV_LIB_DIR" ] && [ -d "$OPENCV_LIB_DIR" ]; then
        export LD_LIBRARY_PATH="${OPENCV_LIB_DIR}:${LD_LIBRARY_PATH}"
        echo "Found OpenCV libraries in: $OPENCV_LIB_DIR" >&2
    else
        echo "Warning: Could not find OpenCV library directory, using default paths" >&2
        # Try to find any opencv library and show what we found
        echo "Searching for OpenCV libraries..." >&2
        find /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib -name "*opencv*" -type f 2>/dev/null | head -5 >&2 || true
    fi
    
    # Update library cache
    ldconfig 2>/dev/null || true
    
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
    
    # Wait a moment to ensure file is fully written and not busy
    # This prevents "Text file busy" errors when build just completed
    sleep 0.5
    
    # Retry mechanism for "Text file busy" error
    max_retries=5
    retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        # Try to run the executable
        # Use PIPESTATUS to capture the actual application exit code, not tee's exit code
        ./"$BUILD"/zoomsdk "$@" 2>&1 | tee -a "$ERROR_LOG"
        EXIT_CODE=${PIPESTATUS[0]}
        
        # If application succeeded, exit successfully
        if [ $EXIT_CODE -eq 0 ]; then
            exit 0
        fi
        
        # Check if it's a "Text file busy" error (exit code 126 or 127, or check stderr)
        if [ $retry_count -lt $((max_retries - 1)) ]; then
            echo "⚠️  Executable busy or error occurred, retrying in 1 second... (attempt $((retry_count + 1))/$max_retries)" >&2
            sleep 1
            retry_count=$((retry_count + 1))
        else
            echo "Application exited with code $EXIT_CODE" >> "$ERROR_LOG"
            echo "❌ Failed to run executable after $max_retries attempts (exit code: $EXIT_CODE)" >&2
            exit $EXIT_CODE
        fi
    done
}

# Build only if needed, then run
build && run "$@";

exit $?

