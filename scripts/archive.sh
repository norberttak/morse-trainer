#!/bin/sh
# Builds a signed App Store archive and exports an .ipa, or uploads it to App Store Connect.
#
#   scripts/archive.sh            archive + export build/export/MorseThanWords.ipa
#   scripts/archive.sh --upload   archive + upload to App Store Connect (then TestFlight)
#
# Needs: DEVELOPMENT_TEAM set in project.yml (then `xcodegen generate`), and your Apple ID
# signed in to Xcode (Settings › Accounts) so automatic signing can create certificates.
set -eu
cd "$(dirname "$0")/.."

TEAM=$(grep -E '^\s+DEVELOPMENT_TEAM:' project.yml | head -1 | awk '{print $2}' | tr -d '"')
if [ -z "$TEAM" ] || [ "$TEAM" = "YOUR_TEAM_ID" ]; then
    echo "error: set DEVELOPMENT_TEAM in project.yml and run 'xcodegen generate' first" >&2
    exit 1
fi

DESTINATION="export"
[ "${1:-}" = "--upload" ] && DESTINATION="upload"

./scripts/check-privacy.sh
./scripts/check-metadata.py >/dev/null

ARCHIVE="build/MorseThanWords.xcarchive"
rm -rf "$ARCHIVE" build/export
xcodebuild archive -project MorseThanWords.xcodeproj -scheme MorseThanWords \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates -quiet

OPTIONS=$(mktemp -t ExportOptions).plist
cat > "$OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>$DESTINATION</string>
    <key>teamID</key><string>$TEAM</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath build/export \
    -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates -quiet
rm -f "$OPTIONS"

if [ "$DESTINATION" = "upload" ]; then
    echo "Uploaded. The build appears in App Store Connect › TestFlight after processing (~15 min)."
else
    echo "Exported: build/export/MorseThanWords.ipa"
fi
