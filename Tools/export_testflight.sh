#!/bin/bash
# Build Cannon Duo for the App Store and push it to TestFlight.
#
#   Tools/export_testflight.sh              bump the build number, build, sign and upload
#   Tools/export_testflight.sh --no-upload  same, but only write build/testflight/CannonDuo.ipa
#
# Steps: bump application/version in export_presets.cfg, export a release Xcode project from
# Godot, archive it with automatic signing, then export the archive straight to App Store
# Connect. The build shows up in TestFlight after Apple finishes processing (5 to 30 minutes).
#
# The team and bundle id come from the "iOS" preset in export_presets.cfg.
#
# Signing and upload log in one of two ways:
#   1. An App Store Connect API key (best, works without Xcode open). Create it under
#      App Store Connect > Users and Access > Integrations > Keys (role: App Manager), save
#      it as ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 and set:
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   2. Otherwise the Apple account signed in to Xcode (Settings > Accounts) is used. It must
#      belong to the team in export_presets.cfg.
#
# Godot: set GODOT=/path/to/Godot, or install it at ~/Applications or /Applications/Godot.app.
set -euo pipefail
cd "$(dirname "$0")/.."

PRESETS=export_presets.cfg
OUT=build/testflight
NAME=CannonDuo
UPLOAD=1
[ "${1:-}" = "--no-upload" ] && UPLOAD=0

fail() { echo "error: $*" >&2; exit 1; }
preset() { grep "^application/$1=" "$PRESETS" | head -1 | cut -d'"' -f2; }

# --- Find the tools ---------------------------------------------------------------------------
if [ -z "${GODOT:-}" ]; then
  for g in "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
           "/Applications/Godot.app/Contents/MacOS/Godot" \
           "$(command -v godot || true)"; do
    if [ -n "$g" ] && [ -x "$g" ]; then GODOT="$g"; break; fi
  done
fi
[ -n "${GODOT:-}" ] && [ -x "$GODOT" ] || fail "Godot not found. Set GODOT=/path/to/Godot."
command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode."

TEAM=$(preset app_store_team_id)
BUNDLE=$(preset bundle_identifier)
VERSION=$(preset short_version)
[ -n "$TEAM" ] && [ -n "$BUNDLE" ] || fail "team or bundle id missing in $PRESETS."

AUTH=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  KEY="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
  [ -f "$KEY" ] || fail "API key not found at $KEY."
  AUTH=(-authenticationKeyPath "$KEY" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  echo "==> Signing with App Store Connect API key $ASC_KEY_ID"
else
  echo "==> Signing with the Apple account signed in to Xcode (no ASC_KEY_ID set)"
fi

# --- Bump the build number ---------------------------------------------------------------------
# Every upload needs a higher build number than the last one. If anything below fails, the
# presets file is put back as it was, so a failed run does not use up a number.
mkdir -p build
cp "$PRESETS" build/.export_presets.backup
restore() {
  status=$?
  if [ $status -ne 0 ]; then
    cp build/.export_presets.backup "$PRESETS"
    echo "==> Failed; $PRESETS restored" >&2
  fi
  rm -f build/.export_presets.backup
  exit $status
}
trap restore EXIT

BUILD=$(( $(preset version | tr -cd '0-9') + 1 ))
sed -i '' "s/^application\/version=.*/application\/version=\"$BUILD\"/" "$PRESETS"
echo "==> $BUNDLE $VERSION ($BUILD), team $TEAM"

# --- Godot: export the Xcode project -----------------------------------------------------------
rm -rf "$OUT"
mkdir -p "$OUT"
echo "==> Importing assets"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "==> Exporting the Xcode project (release)"
sed -i '' 's/^application\/export_project_only=.*/application\/export_project_only=true/' "$PRESETS"
"$GODOT" --headless --path . --export-release "iOS" "$OUT/$NAME.xcodeproj" > "$OUT/godot_export.log" 2>&1 || true
sed -i '' 's/^application\/export_project_only=.*/application\/export_project_only=false/' "$PRESETS"
if [ ! -d "$OUT/$NAME.xcodeproj" ]; then
  grep -E "ERROR|error" "$OUT/godot_export.log" | head -20 >&2 || true
  fail "Godot export failed, full log: $OUT/godot_export.log"
fi

# --- Xcode: archive ------------------------------------------------------------------------------
echo "==> Archiving"
xcodebuild -project "$OUT/$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$OUT/$NAME.xcarchive" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
  CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER="" \
  archive -quiet > "$OUT/archive.log" 2>&1 \
  || { grep -E "error:" "$OUT/archive.log" | head -20 >&2; fail "archive failed, full log: $OUT/archive.log"; }

# --- Xcode: export the IPA, or upload it straight to App Store Connect ------------------------
if [ $UPLOAD -eq 1 ]; then DEST=upload; else DEST=export; fi
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DEST</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>testFlightInternalTestingOnly</key><false/>
</dict>
</plist>
EOF

if [ $UPLOAD -eq 1 ]; then echo "==> Uploading to App Store Connect"; else echo "==> Exporting the IPA"; fi
xcodebuild -exportArchive -archivePath "$OUT/$NAME.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
  > "$OUT/export.log" 2>&1 \
  || { grep -iE "error" "$OUT/export.log" | head -20 >&2; fail "export failed, full log: $OUT/export.log"; }

if [ $UPLOAD -eq 1 ]; then
  echo "==> Uploaded $VERSION ($BUILD). It appears in TestFlight once Apple finishes processing."
else
  echo "==> Done: $OUT/$NAME.ipa ($VERSION, build $BUILD)"
fi
