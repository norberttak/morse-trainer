#!/bin/sh
# Generates App Store screenshots into docs/app-store/screenshots/<device>/.
# Uses the largest required sizes: iPhone 6.9" (1320×2868) and iPad 13" (2064×2752).
set -eu
cd "$(dirname "$0")/.."

OS="26.0"
OUT="docs/app-store/screenshots"

for DEVICE in "iPhone 17 Pro Max" "iPad Pro 13-inch (M5)"; do
    UDID=$(xcrun simctl list devices "iOS $OS" -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
print(next(d['udid'] for runtime in devices.values() for d in runtime if d['name'] == sys.argv[1]))
" "$DEVICE")
    SLUG=$(echo "$DEVICE" | tr -cd 'A-Za-z0-9')
    RESULT="build/results/screenshots-$SLUG.xcresult"
    echo "== $DEVICE ($UDID)"

    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null
    # Classic App Store status bar.
    xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active \
        --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

    rm -rf "$RESULT"
    TEST_RUNNER_SCREENSHOTS=1 xcodebuild test -project MorseThanWords.xcodeproj -scheme MorseThanWords \
        -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/DerivedData \
        -resultBundlePath "$RESULT" -only-testing:MorseThanWordsUITests/ScreenshotUITests -quiet

    xcrun simctl status_bar "$UDID" clear

    rm -rf "$OUT/$SLUG" "build/screenshots-raw"
    mkdir -p "$OUT/$SLUG" "build/screenshots-raw"
    xcrun xcresulttool export attachments --path "$RESULT" --output-path "build/screenshots-raw" >/dev/null
    # The manifest maps exported file names to the attachment names given in the test.
    python3 - "build/screenshots-raw" "$OUT/$SLUG" <<'EOF'
import json, shutil, sys, pathlib
raw, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for test in json.loads((raw / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"].split("_")[0]
        shutil.copy(raw / attachment["exportedFileName"], out / f"{name}.png")
        print("  ", out / f"{name}.png")
EOF
done
