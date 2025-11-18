#!/bin/bash

# Script to create 4 more copies of 20 videos
# Result: video-1.mp4 to video-100.mp4 (20 videos × 5 copies = 100 videos)

VIDEOS_DIR="videos"
ORIGINAL_COUNT=20
COPIES=4  # 4 more copies (total 5 including original)
TOTAL_VIDEOS=$((ORIGINAL_COUNT * (COPIES + 1)))  # 20 × 5 = 100

echo "📹 Creating Video Copies..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if videos directory exists
if [ ! -d "$VIDEOS_DIR" ]; then
    echo "❌ Error: $VIDEOS_DIR directory not found!"
    echo "   Please create the directory and add your 20 videos first."
    exit 1
fi

# Check if original videos exist
MISSING_VIDEOS=0
for i in $(seq 1 $ORIGINAL_COUNT); do
    if [ ! -f "$VIDEOS_DIR/video-$i.mp4" ]; then
        echo "⚠️  Warning: video-$i.mp4 not found"
        MISSING_VIDEOS=$((MISSING_VIDEOS + 1))
    fi
done

if [ $MISSING_VIDEOS -eq $ORIGINAL_COUNT ]; then
    echo "❌ Error: No original videos found in $VIDEOS_DIR/"
    echo "   Expected: video-1.mp4 to video-$ORIGINAL_COUNT.mp4"
    exit 1
fi

if [ $MISSING_VIDEOS -gt 0 ]; then
    echo "⚠️  Warning: $MISSING_VIDEOS videos missing, but continuing..."
    echo ""
fi

# Create copies
echo "📋 Copying Strategy:"
echo "   Original videos: video-1.mp4 to video-$ORIGINAL_COUNT.mp4"
echo "   Creating $COPIES more copies of each"
echo "   Final result: video-1.mp4 to video-$TOTAL_VIDEOS.mp4"
echo ""

COPIED=0
SKIPPED=0

for copy_num in $(seq 1 $COPIES); do
    # Calculate offset for this copy
    OFFSET=$((ORIGINAL_COUNT * copy_num))
    
    echo "📦 Creating copy set $copy_num (offset: +$OFFSET)..."
    
    for i in $(seq 1 $ORIGINAL_COUNT); do
        SOURCE="$VIDEOS_DIR/video-$i.mp4"
        TARGET_NUM=$((i + OFFSET))
        TARGET="$VIDEOS_DIR/video-$TARGET_NUM.mp4"
        
        if [ -f "$SOURCE" ]; then
            if [ -f "$TARGET" ]; then
                echo "  ⏭️  Skipping video-$TARGET_NUM.mp4 (already exists)"
                SKIPPED=$((SKIPPED + 1))
            else
                cp "$SOURCE" "$TARGET"
                if [ $? -eq 0 ]; then
                    echo "  ✅ Copied video-$i.mp4 → video-$TARGET_NUM.mp4"
                    COPIED=$((COPIED + 1))
                else
                    echo "  ❌ Failed to copy video-$i.mp4 → video-$TARGET_NUM.mp4"
                fi
            fi
        fi
    done
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Copy Complete!"
echo ""
echo "📊 Summary:"
echo "   Original videos: $ORIGINAL_COUNT"
echo "   Copies created: $COPIED"
echo "   Skipped (already exist): $SKIPPED"
echo "   Total videos now: $(ls -1 $VIDEOS_DIR/video-*.mp4 2>/dev/null | wc -l)"
echo ""
echo "📁 Video files:"
ls -lh $VIDEOS_DIR/video-*.mp4 2>/dev/null | head -10
if [ $(ls -1 $VIDEOS_DIR/video-*.mp4 2>/dev/null | wc -l) -gt 10 ]; then
    echo "   ... and more"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

