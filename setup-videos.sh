#!/bin/bash

# Script to set up 10 different video files for 10 bots
# Usage: ./setup-videos.sh

echo "📹 Setting up 10 different video files for bots..."

# Create videos directory if it doesn't exist
mkdir -p videos

# Check if output_zoom_ready.mp4 exists (base video)
if [ ! -f "output_zoom_ready.mp4" ]; then
    echo "❌ Error: output_zoom_ready.mp4 not found!"
    echo "   Please create it first using:"
    echo "   ffmpeg -i input-video.mp4 -vf scale=426:240 -r 10 -c:v libx264 -preset ultrafast -profile:v baseline -pix_fmt yuv420p -b:v 50k -maxrate 50k -bufsize 100k -g 30 -an output_zoom_ready.mp4 -y"
    exit 1
fi

# Option 1: Copy same video to different names (if you only have 1 video)
echo ""
echo "Option 1: Copy same video to videos/video-1.mp4 through videos/video-10.mp4"
read -p "Do you want to copy output_zoom_ready.mp4 to videos/video-1.mp4 through videos/video-10.mp4? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for i in {1..10}; do
        cp output_zoom_ready.mp4 "videos/video-${i}.mp4"
        echo "✅ Created videos/video-${i}.mp4"
    done
    echo ""
    echo "✅ All 10 video files created in videos/ folder!"
    echo "   Note: They are all the same video. Replace videos/video-1.mp4 through videos/video-10.mp4"
    echo "   with your actual different videos if needed."
fi

# Option 2: Check if user has 10 different video files
echo ""
echo "Option 2: If you already have 10 different video files,"
echo "   move them to videos/ folder and rename to: video-1.mp4, video-2.mp4, ..., video-10.mp4"
echo ""
echo "Current video files in videos/ folder:"
ls -lh videos/video-*.mp4 2>/dev/null || echo "   No videos/video-*.mp4 files found yet"

echo ""
echo "📋 Next steps:"
echo "   1. Place your 10 different video files in the videos/ folder"
echo "   2. Name them: video-1.mp4, video-2.mp4, ..., video-10.mp4"
echo "   3. Each video should be optimized: 426x240, 10 FPS, H.264 baseline"
echo "   4. Run: docker compose -f compose-50-bots.yaml up --build"

