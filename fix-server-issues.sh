#!/bin/bash

# Script to fix server build and runtime issues
# Fixes: vcpkg cli11 build failures and OpenCV library path issues

echo "🔧 Fixing Server Build Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Issue 1: vcpkg cli11 build failure"
echo "Solution: Using system libcli11-dev instead of vcpkg"
echo ""

echo "Issue 2: OpenCV library not found (libopencv_videoio.so.406)"
echo "Solution: Enhanced LD_LIBRARY_PATH to find OpenCV libraries"
echo ""

echo "✅ Fixes applied to:"
echo "   - Dockerfile: Added libcli11-dev package"
echo "   - CMakeLists.txt: Fallback to system CLI11 if vcpkg fails"
echo "   - entry-bot-optimized.sh: Enhanced OpenCV library path detection"
echo ""

echo "💡 Next steps on server:"
echo "   1. Rebuild Docker image: docker compose build --no-cache"
echo "   2. Or rebuild specific bot: docker compose build bot-1"
echo ""

