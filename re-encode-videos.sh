#!/bin/bash

# Script to re-encode videos to SDK preferred dimensions
# Usage: ./re-encode-videos.sh <target-width> <target-height>
# Example: ./re-encode-videos.sh 640 360

if [ $# -ne 2 ]; then
    echo "Usage: $0 <target-width> <target-height>"
    echo "Example: $0 640 360"
    echo ""
    echo "First, run your bots and check logs for '📐 SDK Preferred Video Dimensions'"
    echo "Then use those dimensions here to re-encode all videos"
    exit 1
fi

TARGET_WIDTH=$1
TARGET_HEIGHT=$2
VIDEOS_DIR="videos"

if [ ! -d "$VIDEOS_DIR" ]; then
    echo "❌ Error: $VIDEOS_DIR directory not found!"
    exit 1
fi

echo "📹 Re-encoding videos in $VIDEOS_DIR to ${TARGET_WIDTH}x${TARGET_HEIGHT}..."
echo ""

# Find all video files
VIDEO_FILES=$(find "$VIDEOS_DIR" -name "*.mp4" -type f | sort)

if [ -z "$VIDEO_FILES" ]; then
    echo "❌ No video files found in $VIDEOS_DIR"
    exit 1
fi

# Re-encode each video
for video in $VIDEO_FILES; do
    filename=$(basename "$video")
    temp_file="${video}.tmp"
    
    echo "Processing: $filename"
    
    # Re-encode with optimized settings
    ffmpeg -i "$video" \
        -vf "scale=${TARGET_WIDTH}:${TARGET_HEIGHT}" \
        -r 10 \
        -c:v libx264 \
        -preset ultrafast \
        -profile:v baseline \
        -pix_fmt yuv420p \
        -b:v 50k \
        -maxrate 50k \
        -bufsize 100k \
        -g 30 \
        -an \
        -y \
        "$temp_file" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$video"
        echo "✅ Re-encoded: $filename"
    else
        echo "❌ Failed: $filename"
        rm -f "$temp_file"
    fi
    echo ""
done

echo "✅ All videos re-encoded to ${TARGET_WIDTH}x${TARGET_HEIGHT}!"
echo "Now rebuild and run your bots!"

