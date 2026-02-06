#!/usr/bin/env bash

set -euo pipefail

COUNT="${1:-20}"
BASE="${2:-5}"
LABEL_PREFIX="${3:-BotCamAudio}"
EXCLUSIVE_CAPS="${4:-0}"

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -le 0 ]; then
  echo "COUNT must be a positive integer" >&2
  exit 1
fi
if ! [[ "$BASE" =~ ^[0-9]+$ ]] || [ "$BASE" -le 0 ]; then
  echo "BASE must be a positive integer" >&2
  exit 1
fi

video_nr=$(seq -s, "$BASE" "$((BASE + COUNT - 1))")
labels=$(seq -s, -f "${LABEL_PREFIX}%g" 1 "$COUNT")

echo "Creating v4l2loopback devices:"
echo "  COUNT=$COUNT BASE=/dev/video$BASE..$((BASE + COUNT - 1))"
echo "  LABEL_PREFIX=$LABEL_PREFIX"
echo "  EXCLUSIVE_CAPS=$EXCLUSIVE_CAPS"

sudo modprobe -r v4l2loopback || true
sudo modprobe v4l2loopback devices="$COUNT" video_nr="$video_nr" card_label="$labels" exclusive_caps="$EXCLUSIVE_CAPS"

ls -l "/dev/video${BASE}" "/dev/video$((BASE + COUNT - 1))"
