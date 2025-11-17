#!/bin/bash

# Script to encode videos for Zoom SDK
# Optimized settings for 50 bots: 640x360 @ 10 FPS

TARGET_WIDTH=640
TARGET_HEIGHT=360
FPS=10
VIDEOS_DIR="videos"

echo "📹 Encoding videos for Zoom SDK..."
echo "Settings: ${TARGET_WIDTH}x${TARGET_HEIGHT} @ ${FPS} FPS"
echo ""

if [ ! -d "$VIDEOS_DIR" ]; then
    echo "Creating $VIDEOS_DIR directory..."
    mkdir -p "$VIDEOS_DIR"
fi

# Check if videos exist
VIDEO_FILES=$(find "$VIDEOS_DIR" -name "*.mp4" -type f 2>/dev/null | sort)

if [ -z "$VIDEO_FILES" ]; then
    echo "ℹ️  No videos found in $VIDEOS_DIR"
    echo "Place your source videos in $VIDEOS_DIR/ and name them:"
    echo "  video-1.mp4, video-2.mp4, ..., video-10.mp4"
    echo ""
    echo "Or if you have source videos elsewhere, specify:"
    echo "  ./encode-zoom-videos.sh /path/to/source/videos"
    exit 0
fi

echo "Found videos:"
echo "$VIDEO_FILES"
echo ""

read -p "Re-encode all videos to ${TARGET_WIDTH}x${TARGET_HEIGHT} @ ${FPS} FPS? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Encode each video
for video in $VIDEO_FILES; do
    filename=$(basename "$video")
    temp_file="${video}.tmp"
    
    echo ""
    echo "Processing: $filename"
    
    # Zoom SDK optimized settings
    ffmpeg -i "$video" \
        -vf "scale=${TARGET_WIDTH}:${TARGET_HEIGHT}:force_original_aspect_ratio=decrease,pad=${TARGET_WIDTH}:${TARGET_HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
        -r ${FPS} \
        -c:v libx264 \
        -preset ultrafast \
        -profile:v baseline \
        -level 3.0 \
        -pix_fmt yuv420p \
        -b:v 250k \
        -maxrate 250k \
        -bufsize 500k \
        -g ${FPS} \
        -keyint_min ${FPS} \
        -sc_threshold 0 \
        -an \
        -movflags +faststart \
        -y \
        "$temp_file" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Backup original
        mv "$video" "${video}.backup"
        mv "$temp_file" "$video"
        echo "✅ Encoded: $filename (original saved as ${filename}.backup)"
    else
        echo "❌ Failed: $filename"
        rm -f "$temp_file"
    fi
done

echo ""
echo "✅ All videos encoded for Zoom SDK!"
echo "Settings: ${TARGET_WIDTH}x${TARGET_HEIGHT} @ ${FPS} FPS, H.264 baseline"
echo ""
echo "Original videos backed up with .backup extension"

