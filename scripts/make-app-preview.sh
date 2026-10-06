#!/bin/sh
# Records the App Store app preview for the iPhone 6.3" display class:
# docs/app-store/preview/app-preview-iphone.mp4 — 886×1920, H.264, 30 fps, 15–30 s,
# with a silent stereo AAC track (the simulator recorder captures no audio).
set -eu
cd "$(dirname "$0")/.."

DEVICE="iPhone 17 Pro"
OS="26.0"
OUT="docs/app-store/preview"
RAW="build/preview-raw.mov"
MARKS="build/preview-marks.txt"

UDID=$(xcrun simctl list devices "iOS $OS" -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
print(next(d['udid'] for runtime in devices.values() for d in runtime if d['name'] == sys.argv[1]))
" "$DEVICE")
echo "== $DEVICE ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

# Build first, so the recording only covers the test itself.
xcodebuild build-for-testing -project MorseThanWords.xcodeproj -scheme MorseThanWords \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/DerivedData -quiet

mkdir -p build "$OUT"
rm -f "$RAW" "$MARKS"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$RAW" &
RECORDER=$!
sleep 2  # let the recorder start
START=$(python3 -c "import time; print(time.time())")

# Timestamp the PREVIEW_MARK lines relative to the recording start.
TEST_RUNNER_APP_PREVIEW=1 xcodebuild test-without-building -project MorseThanWords.xcodeproj \
    -scheme MorseThanWords -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath build/DerivedData -only-testing:MorseThanWordsUITests/AppPreviewUITests 2>&1 |
    python3 -c "
import sys, time
start = float(sys.argv[1]) - 2  # recorder started 2 s before START
with open(sys.argv[2], 'w') as marks:
    for line in sys.stdin:
        if 'PREVIEW_MARK' in line and 'print' not in line:
            name = line.split('PREVIEW_MARK', 1)[1].split()[0]
            marks.write(f'{name} {time.time() - start:.2f}\n')
            marks.flush()
        if 'error' in line.lower() and 'Test Case' in line:
            print(line, end='')
" "$START" "$MARKS"

kill -INT "$RECORDER"
wait "$RECORDER" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear

cat "$MARKS"
FROM=$(awk '$1 == "start" {print $2}' "$MARKS")
TO=$(awk '$1 == "end" {print $2}' "$MARKS")
LENGTH=$(python3 -c "print(min(29.0, $TO - $FROM))")  # Apple allows 15–30 s
echo "cut: from $FROM s, length $LENGTH s"

# 1206×2622 → 886×1926 → center-crop to 886×1920; constant 30 fps; silent stereo AAC.
ffmpeg -y -loglevel error -ss "$FROM" -t "$LENGTH" -i "$RAW" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
    -vf "scale=886:-2,crop=886:1920,fps=30,format=yuv420p" \
    -c:v libx264 -profile:v high -level 4.1 -preset slow -crf 18 \
    -c:a aac -b:a 256k -shortest -movflags +faststart \
    "$OUT/app-preview-iphone.mp4"

ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,channels -show_entries format=duration \
    -of compact "$OUT/app-preview-iphone.mp4"
