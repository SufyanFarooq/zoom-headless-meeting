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
    for _ in $(seq 1 20); do
      [ -S "/tmp/.X11-unix/X99" ] && break
      sleep 0.1
    done
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

  # Wait for pulseaudio to start (poll instead of fixed 1s sleep)
  for _ in $(seq 1 20); do
    if pactl info > /dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

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
  mkdir -p "$BUILD"

  # Use a shared lock so only one container does heavy build/cmake checks.
  # Other containers can skip quickly when cache is already ready.
  local BUILD_STAMP="$BUILD/.build-ready"
  local BUILD_LOCK="$BUILD/.build.lock"
  local CURRENT_PLATFORM=$(uname -m)-$(uname -s)
  local BOT_BUILD_TYPE="${BOT_BUILD_TYPE:-Release}"
  local lock_enabled=false
  local LOCK_WAIT_SECONDS="${BUILD_LOCK_WAIT_SECONDS:-1800}"

  cache_ready_quick() {
    if [[ ! -f "$BUILD/zoomsdk" || ! -f "$BUILD_STAMP" ]]; then
      return 1
    fi
    if [[ -f "$BUILD/.platform" ]]; then
      CACHED_PLATFORM=$(cat "$BUILD/.platform" 2>/dev/null || echo "")
      if [[ "$CACHED_PLATFORM" != "$CURRENT_PLATFORM" ]]; then
        return 1
      fi
    fi
    if ldd "$BUILD/zoomsdk" 2>&1 | grep -q "version.*not found"; then
      return 1
    fi
    return 0
  }

  cache_ready_full() {
    if ! cache_ready_quick; then
      return 1
    fi
    for src_path in src CMakeLists.txt CMakePresets.json; do
      if [ -e "$src_path" ] && find "$src_path" -type f -newer "$BUILD_STAMP" 2>/dev/null | grep -q .; then
        return 1
      fi
    done
    return 0
  }

  # Fast path (no lock): if cache is valid, skip heavy build checks immediately.
  if cache_ready_full; then
    echo "Build cache ready, skipping build checks..." >&2
    setup-pulseaudio
    return 0
  fi

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$BUILD_LOCK"
    if ! flock -n 9; then
      echo "Build lock busy, waiting for another container to finish build checks..." >&2
      local waited=0
      while [ "$waited" -lt "$LOCK_WAIT_SECONDS" ]; do
        if cache_ready_quick; then
          echo "Build cache became ready, skipping local build checks..." >&2
          exec 9>&-
          setup-pulseaudio
          return 0
        fi
        sleep 1
        waited=$((waited + 1))
      done
      # Fallback: keep waiting on lock instead of failing containers.
      # First build may take long (vcpkg/openssl), so failing here causes repeated join delays.
      echo "Still waiting for build lock after ${LOCK_WAIT_SECONDS}s..." >&2
      flock 9
    fi
    lock_enabled=true
  fi

  # Re-check after lock (another container may have completed build meanwhile).
  if cache_ready_full; then
    echo "Build cache ready, skipping build checks..." >&2
    if [[ "$lock_enabled" == "true" ]]; then
      flock -u 9 || true
      exec 9>&-
    fi
    setup-pulseaudio
    return 0
  fi

  # CRITICAL: Detect cross-platform build cache (e.g. Mac .o files in Linux container)
  # Shared volume /tmp/build-cache may contain artifacts from different host
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
      if ! cmake -B "$BUILD" -S . --preset debug -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" > /dev/null 2>&1; then
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
    cmake -B "$BUILD" -S . --preset debug -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" 2>&1 | tee /tmp/build-logs/cmake.log
    CMAKE_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $CMAKE_EXIT_CODE -ne 0 ]; then
      echo "CMake with preset failed, trying without vcpkg toolchain..." >&2
      # Configure without vcpkg toolchain (system packages only)
      cmake -B "$BUILD" -S . \
        -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" \
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
        cmake -B "$BUILD" -S . --preset debug -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" 2>&1 | tee /tmp/build-logs/cmake.log || {
          cmake -B "$BUILD" -S . \
            -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" \
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
        cmake -B "$BUILD" -S . --preset debug -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" 2>/dev/null || cmake -B "$BUILD" -S . -DCMAKE_BUILD_TYPE="$BOT_BUILD_TYPE" -DCMAKE_CXX_STANDARD=20 2>/dev/null
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

  # Mark cache as ready for other concurrently starting containers.
  touch "$BUILD_STAMP"

  if [[ "$lock_enabled" == "true" ]]; then
    flock -u 9 || true
    exec 9>&-
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
    
    # Resolve OpenCV dir quickly (avoid scanning hundreds of libraries per container start).
    OPENCV_LIB_DIR=""
    for search_dir in /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib; do
        if [ -e "$search_dir/libopencv_core.so" ] || ls "$search_dir"/libopencv_core.so.* >/dev/null 2>&1; then
            OPENCV_LIB_DIR="$search_dir"
            break
        fi
    done
    if [ -z "$OPENCV_LIB_DIR" ] && command -v pkg-config >/dev/null 2>&1; then
        OPENCV_LIB_DIR=$(pkg-config --variable=libdir opencv4 2>/dev/null || pkg-config --variable=libdir opencv 2>/dev/null)
    fi
    if [ -n "$OPENCV_LIB_DIR" ] && [ -d "$OPENCV_LIB_DIR" ]; then
        export LD_LIBRARY_PATH="${OPENCV_LIB_DIR}:${LD_LIBRARY_PATH}"
    fi

    ensure_opencv_compat_links() {
        local exe="./$BUILD/zoomsdk"
        if [ ! -x "$exe" ] || [ -z "$OPENCV_LIB_DIR" ] || [ ! -d "$OPENCV_LIB_DIR" ]; then
            return 0
        fi

        local required_libs
        required_libs=$(ldd "$exe" 2>/dev/null | awk '/libopencv_/ {print $1}' | sort -u)
        if [ -z "$required_libs" ]; then
            return 0
        fi

        local lock_fd_opened=false
        if command -v flock >/dev/null 2>&1; then
            exec 8>/tmp/opencv-link.lock
            flock -w 5 8 || true
            lock_fd_opened=true
        fi

        local created=0
        for req_lib in $required_libs; do
            if [ -e "$OPENCV_LIB_DIR/$req_lib" ] || [ -e "/usr/lib/$req_lib" ] || [ -e "/usr/lib/x86_64-linux-gnu/$req_lib" ] || [ -e "/usr/local/lib/$req_lib" ]; then
                continue
            fi
            local lib_base="${req_lib%%.so*}"
            local candidate
            candidate=$(find "$OPENCV_LIB_DIR" -maxdepth 1 -type f -name "${lib_base}.so.*" 2>/dev/null | sort -rV | head -1)
            if [ -n "$candidate" ]; then
                if ln -sf "$(basename "$candidate")" "$OPENCV_LIB_DIR/$req_lib" 2>/dev/null; then
                    created=$((created + 1))
                fi
            fi
        done

        if [ "$created" -gt 0 ]; then
            echo "Created $created OpenCV compatibility symlink(s)" >&2
            ldconfig 2>/dev/null || true
        fi

        if [ "$lock_fd_opened" = true ]; then
            flock -u 8 || true
            exec 8>&-
        fi
    }
    ensure_opencv_compat_links
    
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
    
    # Debug: Log command arguments only when explicitly enabled
    if [ "${ENTRY_DEBUG_ARGS:-false}" = "true" ] && echo "$@" | grep -q "\--zak"; then
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
