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

# Start Xvfb (virtual display) - Zoom desktop app needs this to show video icon for participants
# Without it, web shows disabled icon but desktop app shows no icon at all
setup-xvfb() {
  export DISPLAY=:99
  if [ ! -S "/tmp/.X11-unix/X99" ]; then
    Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &
    sleep 2
  fi
}

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

  # Create virtual sink + source so Zoom SDK detects audio device (fixes raw audio status 12)
  pactl load-module module-null-sink sink_name=SpeakerOutput > /dev/null 2>&1
  pactl set-default-sink SpeakerOutput > /dev/null 2>&1
  pactl set-default-source SpeakerOutput.monitor > /dev/null 2>&1

  # DummyMic - Zoom SDK needs to detect a microphone for raw audio subscription
  pactl load-module module-null-source source_name=DummyMic > /dev/null 2>&1
  pactl set-default-source DummyMic > /dev/null 2>&1 || true

  # ALSA -> PulseAudio: Zoom may use ALSA directly; route to Pulse virtual devices
  mkdir -p ~/.config
  cat > ~/.asoundrc << 'ASOUND'
pcm.!default { type pulse }
ctl.!default { type pulse }
ASOUND

  # Verify audio devices
  if command -v pactl > /dev/null 2>&1; then
    if ! pactl list short sources 2>/dev/null | grep -q -E "DummyMic|SpeakerOutput"; then
      echo "Warning: PulseAudio virtual source not created" >&2
    fi
  fi

  echo -e "[General]\nsystem.audio.type=default" > ~/.config/zoomus.conf 2>/dev/null
}

build() {
  # Start Xvfb early - Zoom desktop app needs virtual display to show video icon
  setup-xvfb
  
  # Log build start
  echo "Starting build process..." >&2

  # CRITICAL: Detect cross-platform build cache (e.g. Mac .o files in Linux container)
  # Shared volume /tmp/build-cache may contain artifacts from different host
  CURRENT_PLATFORM=$(uname -m)-$(uname -s)
  if [[ -d "$BUILD" ]] && [[ -f "$BUILD/.platform" ]]; then
    CACHED_PLATFORM=$(cat "$BUILD/.platform" 2>/dev/null || echo "")
    if [[ "$CACHED_PLATFORM" != "$CURRENT_PLATFORM" ]]; then
      echo "Platform mismatch: cache=$CACHED_PLATFORM current=$CURRENT_PLATFORM - cleaning build..." >&2
      rm -rf "$BUILD"/* "$BUILD"/.[!.]* 2>/dev/null || rm -rf "$BUILD"/* 2>/dev/null
    fi
  fi
  # Also check: if .o files exist, verify they're ELF (Linux) not Mach-O (Mac)
  if [[ -f "$BUILD/CMakeFiles/zoomsdk.dir/src/Zoom.cpp.o" ]]; then
    OFORMAT=$(file -b "$BUILD/CMakeFiles/zoomsdk.dir/src/Zoom.cpp.o" 2>/dev/null || echo "")
    if echo "$OFORMAT" | grep -qi "Mach-O"; then
      echo "Build cache contains Mac object files but running on $(uname -s) - cleaning..." >&2
      rm -rf "$BUILD"/* "$BUILD"/.[!.]* 2>/dev/null || rm -rf "$BUILD"/* 2>/dev/null
    fi
  fi
  
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
    mkdir -p /tmp/build-logs
    
    # Try preset first, but if it fails due to vcpkg, try without preset
    # Use PIPESTATUS to capture cmake's exit code, not tee's
    cmake -B "$BUILD" -S . --preset debug 2>&1 | tee /tmp/build-logs/cmake.log
    CMAKE_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $CMAKE_EXIT_CODE -ne 0 ]; then
      echo "CMake with preset failed, trying without vcpkg toolchain..." >&2
      # Configure without vcpkg toolchain (system packages only)
      cmake -B "$BUILD" -S . \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        2>&1 | tee /tmp/build-logs/cmake.log
      CMAKE_EXIT_CODE=${PIPESTATUS[0]}
      
      if [ $CMAKE_EXIT_CODE -ne 0 ]; then
        echo "ERROR: CMake configuration failed" >&2
        cat /tmp/build-logs/cmake.log >&2
        exit 1
      fi
    fi
    # Stamp platform so we detect cross-host cache reuse
    echo "$CURRENT_PLATFORM" > "$BUILD/.platform" 2>/dev/null || true
  else
    echo "Build directory exists, skipping cmake..." >&2
    mkdir -p /tmp/build-logs
    # Check if executable exists and was built on a different system (GLIBC mismatch)
    if [ -f "$BUILD/zoomsdk" ]; then
      # Check if executable requires newer GLIBC than available
      if ldd "$BUILD/zoomsdk" 2>&1 | grep -q "version.*not found"; then
        echo "⚠️  Executable was built on a different system (GLIBC mismatch)" >&2
        echo "⚠️  Rebuilding to match container's GLIBC version..." >&2
        # Force rebuild by removing executable and build artifacts
        rm -f "$BUILD/zoomsdk" "$BUILD/CMakeCache.txt" 2>/dev/null || true
        # Re-run cmake configuration
        cmake -B "$BUILD" -S . --preset debug 2>&1 | tee /tmp/build-logs/cmake.log || {
          cmake -B "$BUILD" -S . \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_CXX_STANDARD=20 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            2>&1 | tee /tmp/build-logs/cmake.log
        }
      fi
    fi
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
  # Check if executable was built on a different system (GLIBC mismatch)
  elif ldd "$BUILD/zoomsdk" 2>&1 | grep -q "version.*not found"; then
    echo "⚠️  Executable GLIBC mismatch detected, rebuilding..." >&2
    NEED_REBUILD=true
  elif [[ "src/Zoom.h" -nt "$BUILD/zoomsdk" ]] || [[ "src/Zoom.cpp" -nt "$BUILD/zoomsdk" ]]; then
    echo "Source files changed, rebuilding..." >&2
    NEED_REBUILD=true
  fi
  
  # Build only if needed
  if [[ "$NEED_REBUILD" == "true" ]]; then
    echo "Building application..." >&2
    mkdir -p /tmp/build-logs
    # Reduce parallelism to avoid OOM (use 1 job to minimize memory usage)
    # This prevents "Killed signal terminated program cc1plus" errors
    # Also limit compiler memory usage with flags to reduce memory footprint
    # Use CMAKE_CXX_FLAGS to ensure flags are passed to all compilation units
    export CXXFLAGS="${CXXFLAGS} -fno-var-tracking -fno-var-tracking-assignments -Os"
    # Set CMAKE_CXX_FLAGS via cmake to ensure it's used
    cmake -B "$BUILD" -DCMAKE_CXX_FLAGS="${CXXFLAGS}" 2>/dev/null || true
    cmake --build "$BUILD" -j1 2>&1 | tee /tmp/build-logs/build.log
    BUILD_EXIT=${PIPESTATUS[0]}
    if [ $BUILD_EXIT -ne 0 ]; then
      # If "file format not recognized" = cross-platform cache (Mac .o on Linux)
      if [ -f /tmp/build-logs/build.log ] && grep -q "file format not recognized\|file not recognized" /tmp/build-logs/build.log 2>/dev/null; then
        echo "Cross-platform build cache detected - cleaning and retrying..." >&2
        rm -rf "$BUILD"/* "$BUILD"/.[!.]* 2>/dev/null || rm -rf "$BUILD"/* 2>/dev/null
        cmake -B "$BUILD" -S . --preset debug 2>/dev/null || cmake -B "$BUILD" -S . -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=20 2>/dev/null
        echo "$CURRENT_PLATFORM" > "$BUILD/.platform" 2>/dev/null || true
        cmake --build "$BUILD" -j1 2>&1 | tee /tmp/build-logs/build.log
        BUILD_EXIT=${PIPESTATUS[0]}
      fi
      if [ $BUILD_EXIT -ne 0 ]; then
        echo "ERROR: Build failed" >&2
        [ -f /tmp/build-logs/build.log ] && cat /tmp/build-logs/build.log >&2
      fi
      # If build failed due to OOM, suggest increasing memory or building outside container
      if [ $BUILD_EXIT -ne 0 ] && [ -f /tmp/build-logs/build.log ] && grep -q "Killed\|signal terminated\|out of memory" /tmp/build-logs/build.log 2>/dev/null; then
        echo "" >&2
        echo "⚠️  Build failed due to out of memory (OOM)." >&2
        echo "💡 Solutions:" >&2
        echo "   1. Increase container memory limit in compose file:" >&2
        echo "      memory: 1G  # or higher (currently 512M may be too low)" >&2
        echo "   2. Build outside container and copy executable" >&2
        echo "   3. Use a build service with more memory" >&2
        echo "" >&2
        echo "Current memory limit may be too low for C++ compilation" >&2
      fi
      unset CXXFLAGS
      exit 1
    fi
    unset CXXFLAGS
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
    # Ensure we're in the correct working directory
    cd /tmp/meeting-sdk-linux-sample || {
        echo "❌ Failed to change to working directory: /tmp/meeting-sdk-linux-sample" >&2
        exit 1
    }
    
    # Debug: Verify videos folder exists
    if [ ! -d "videos" ]; then
        echo "⚠️  Warning: videos folder not found in $(pwd)" >&2
        echo "   Creating videos directory..." >&2
        mkdir -p videos
    fi
    
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
        
        # Fix version mismatch: Create symlinks for common version mismatches
        # The binary may expect specific versions (.406, .4.5) but system has different versions (4.6.x, 4.8.x, etc.)
        # Create symlinks to bridge these mismatches for any OpenCV 4.x version
        # Find ALL OpenCV libraries (not just a hardcoded list) to handle any dependencies
        echo "Checking OpenCV library versions..." >&2
        
        # Get list of all OpenCV libraries found in the directory
        ALL_OPENCV_LIBS=$(find "$OPENCV_LIB_DIR" -name "libopencv_*.so.*" -type f 2>/dev/null | sed 's|.*/libopencv_||' | sed 's|\.so\..*||' | sort -u)
        
        # Also include common libraries that might be needed
        COMMON_LIBS="videoio core imgproc imgcodecs objdetect calib3d features2d flann highgui ml photo stitching video"
        
        # Combine and deduplicate
        ALL_LIBS=$(echo "$ALL_OPENCV_LIBS $COMMON_LIBS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
        
        for lib_name in $ALL_LIBS; do
            # Find all versions of this library and get the highest (most recent) version
            # Use sort -rV (reverse version sort) to get highest version first
            ACTUAL_VERSION=$(find "$OPENCV_LIB_DIR" -name "libopencv_${lib_name}.so.*" -type f 2>/dev/null | sed "s|.*\.so\.||" | sort -rV | head -1)
            
            if [ -n "$ACTUAL_VERSION" ]; then
                echo "Found libopencv_${lib_name}.so.${ACTUAL_VERSION}" >&2
                
                # Extract major.minor version (e.g., "4.6" from "4.6.1" or "4.8" from "4.8.0")
                # This helps identify OpenCV 4.x versions generically
                MAJOR_MINOR=$(echo "$ACTUAL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
                MAJOR_ONLY=$(echo "$ACTUAL_VERSION" | sed -E 's/^([0-9]+).*/\1/')
                
                # Create symlinks for common required versions that binaries might expect
                # These are the versions searched in Method 2 (line 202): 406, 4.5, 4.8, 4.6, 4.0
                REQUIRED_VERSIONS="406 4.5 4.8 4.6 4.0"
                
                # If we have any OpenCV 4.x version, create symlinks to common required versions
                if [ "$MAJOR_ONLY" = "4" ]; then
                    for req_version in $REQUIRED_VERSIONS; do
                        # Skip if the required version is the same as actual (or very close)
                        if [ "$req_version" != "$ACTUAL_VERSION" ] && [ "$req_version" != "$MAJOR_MINOR" ]; then
                            if [ ! -f "$OPENCV_LIB_DIR/libopencv_${lib_name}.so.${req_version}" ]; then
                                echo "Creating symlink: libopencv_${lib_name}.so.${req_version} -> libopencv_${lib_name}.so.${ACTUAL_VERSION}" >&2
                                ln -sf "libopencv_${lib_name}.so.${ACTUAL_VERSION}" "$OPENCV_LIB_DIR/libopencv_${lib_name}.so.${req_version}" 2>/dev/null || true
                            fi
                        fi
                    done
                fi
            fi
        done
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
    ERROR_LOG="/tmp/build-logs/error.log"
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
    
    # Debug: Log command arguments to help diagnose ZAK token issues
    if echo "$@" | grep -q "\--zak"; then
        echo "🔍 DEBUG: Command arguments (showing --zak occurrences):" >&2
        zak_count=0
        for arg in "$@"; do
            if [ "$arg" = "--zak" ] || [ "$arg" = "-z" ]; then
                zak_count=$((zak_count + 1))
                echo "  Found --zak at position (count: $zak_count)" >&2
            fi
        done
        echo "  Total --zak count: $zak_count" >&2
    fi
    
    # Timeout: leave meeting after TIMEOUT_SECONDS (from dashboard)
    run_zoomsdk() {
        if [ -n "${TIMEOUT_SECONDS:-}" ] && [ "$TIMEOUT_SECONDS" -gt 0 ] 2>/dev/null; then
            echo "⏱  Bot will leave meeting after ${TIMEOUT_SECONDS}s" >&2
            timeout "$TIMEOUT_SECONDS" ./"$BUILD"/zoomsdk "$@"
        else
            ./"$BUILD"/zoomsdk "$@"
        fi
    }

    while [ $retry_count -lt $max_retries ]; do
        run_zoomsdk "$@" 2>&1 | tee -a "$ERROR_LOG"
        EXIT_CODE=${PIPESTATUS[0]}
        
        # 0=normal exit, 124=timeout (bot left after TIMEOUT_SECONDS)
        if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
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

