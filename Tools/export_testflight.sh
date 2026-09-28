#!/bin/sh
# Build an App Store signed IPA for TestFlight: bumps the build number, exports a release Xcode
# project from Godot, archives it with automatic signing (Xcode makes the distribution
# certificate and profile if needed) and exports build/testflight/CannonDuo.ipa.
#
#   Tools/export_testflight.sh           build the IPA
#   Tools/export_testflight.sh --upload  build and upload to App Store Connect (needs an API key,
#                                        see the end of this file)
set -e
cd "$(dirname "$0")/.."
GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
OUT=build/testflight
TEAM=S246Z44JS6

# Every upload needs a higher build number (the version stays 1.0).
BUILD=$(grep '^application/version=' export_presets.cfg | sed 's/[^0-9]//g')
BUILD=$((BUILD + 1))
sed -i '' "s/^application\/version=.*/application\/version=\"$BUILD\"/" export_presets.cfg
echo "==> Version $(grep '^application/short_version=' export_presets.cfg | cut -d'"' -f2), build $BUILD"

rm -rf "$OUT"
mkdir -p "$OUT"
echo "==> Importing"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "==> Exporting the Xcode project (release)"
sed -i '' 's/^application\/export_project_only=false/application\/export_project_only=true/' export_presets.cfg
"$GODOT" --headless --path . --export-release "iOS" "$OUT/CannonDuo.xcodeproj" 2>&1 | grep -E "EXPORT|error:|ERROR" || true
sed -i '' 's/^application\/export_project_only=true/application\/export_project_only=false/' export_presets.cfg

echo "==> Archiving (automatic App Store signing)"
xcodebuild -project "$OUT/CannonDuo.xcodeproj" -scheme CannonDuo -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$OUT/CannonDuo.xcarchive" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER="" \
  archive -quiet

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict>
</plist>
EOF

echo "==> Exporting the IPA"
xcodebuild -exportArchive -archivePath "$OUT/CannonDuo.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates -quiet
echo "==> Done: $OUT/CannonDuo.ipa"

# Upload: needs an App Store Connect API key (Users and Access > Integrations > Keys), saved as
# ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8, with ASC_KEY_ID and ASC_ISSUER_ID set.
if [ "$1" = "--upload" ]; then
  echo "==> Uploading to App Store Connect"
  xcrun altool --upload-app -f "$OUT/CannonDuo.ipa" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
fi
