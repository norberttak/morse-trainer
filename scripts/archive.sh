#!/bin/sh
# Builds a signed App Store .ipa: build/export/MorseThanWords.ipa
# Upload it with Apple's Transporter app (sign in with your Apple ID, drag the .ipa in).
#
# Why not let Xcode upload directly: Xcode's distribution re-signing writes the certificate name
# "Apple Distribution: NORBERT TAKÁCS" into the signature's designated requirement in decomposed
# Unicode (A + combining accent), while the certificate stores a precomposed "Á". The signature
# then fails its own requirement and App Store Connect rejects it ("Invalid Signature"). Signing
# locally with codesign encodes it correctly, so the exported app is re-signed here.
#
# Needs: DEVELOPMENT_TEAM in project.yml, your Apple ID in Xcode › Settings › Accounts, at least one
# registered device, and a local Apple Distribution certificate (Manage Certificates › + ).
set -eu
cd "$(dirname "$0")/.."

TEAM=$(grep -E '^\s+DEVELOPMENT_TEAM:' project.yml | head -1 | awk '{print $2}' | tr -d '"')
if [ -z "$TEAM" ]; then
    echo "error: set DEVELOPMENT_TEAM in project.yml and run 'xcodegen generate' first" >&2
    exit 1
fi

IDENTITY=$(security find-identity -v -p codesigning | awk -v team="($TEAM)" '/"Apple Distribution: / && index($0, team) {print $2; exit}')
if [ -z "$IDENTITY" ]; then
    echo "error: no local Apple Distribution certificate for team $TEAM" >&2
    echo "       create one in Xcode › Settings › Accounts › Manage Certificates › + › Apple Distribution" >&2
    exit 1
fi

./scripts/check-privacy.sh
./scripts/check-metadata.py >/dev/null

ARCHIVE="build/MorseThanWords.xcarchive"
EXPORT="build/export"
WORK="build/resign"
rm -rf "$ARCHIVE" "$EXPORT" "$WORK"

# Automatic signing archives with a development profile, which needs at least one device on the
# team; -allowProvisioningDeviceRegistration registers devices paired with this Mac.
xcodebuild archive -project MorseThanWords.xcodeproj -scheme MorseThanWords \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet

OPTIONS=$(mktemp -t ExportOptions).plist
cat > "$OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>export</string>
    <key>teamID</key><string>$TEAM</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
    -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates -quiet
rm -f "$OPTIONS"

# Re-sign locally with a correctly encoded designated requirement.
mkdir -p "$WORK"
unzip -q "$EXPORT/MorseThanWords.ipa" -d "$WORK"
APP="$WORK/Payload/MorseThanWords.app"

# The embedded App Store profile must allow the certificate we sign with.
security cms -D -i "$APP/embedded.mobileprovision" > "$WORK/profile.plist"
python3 - "$WORK/profile.plist" "$IDENTITY" <<'EOF'
import hashlib, plistlib, sys
profile = plistlib.load(open(sys.argv[1], "rb"))
hashes = {hashlib.sha1(cert).hexdigest().upper() for cert in profile["DeveloperCertificates"]}
if sys.argv[2] not in hashes:
    sys.exit(f"error: profile '{profile['Name']}' does not include certificate {sys.argv[2]}; "
             "run again so Xcode refreshes the profile")
print(f"profile: {profile['Name']}")
EOF

codesign --force --sign "$IDENTITY" --preserve-metadata=entitlements --generate-entitlement-der "$APP"
codesign --verify --deep --strict "$APP"   # fails unless the signature satisfies its requirement
codesign -dvv "$APP" 2>&1 | grep '^Authority=Apple Distribution'

rm "$EXPORT/MorseThanWords.ipa"
(cd "$WORK" && zip -qry ../export/MorseThanWords.ipa Payload)
echo "Ready: $EXPORT/MorseThanWords.ipa — upload it with the Transporter app."
