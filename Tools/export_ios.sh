#!/bin/sh
# Export the Godot project to an iOS Xcode project and IPA, then install on the connected iPhone.
#
#   Tools/export_ios.sh            export and install
#   Tools/export_ios.sh --no-install
set -e
cd "$(dirname "$0")/.."
GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
mkdir -p build/ios
echo "==> Importing"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "==> Exporting iOS"
"$GODOT" --headless --path . --export-debug "iOS" build/ios/CannonDuo.xcodeproj 2>&1 | grep -E "EXPORT|error:|ERROR" || true
if [ "$1" != "--no-install" ]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep -i physical | grep -oE "[0-9A-F]{8}-[0-9A-F]{16}" | head -1)
  if [ -n "$DEVICE" ]; then
    echo "==> Installing on $DEVICE"
    xcrun devicectl device install app --device "$DEVICE" build/ios/CannonDuo.ipa | grep -i installed
    xcrun devicectl device process launch --device "$DEVICE" com.faufaufau.cannonduo.godot | tail -1
  else
    echo "No iPhone connected; IPA is at build/ios/CannonDuo.ipa"
  fi
fi
