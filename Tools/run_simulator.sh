#!/bin/sh
# Build the game for the iOS Simulator and launch it there.
#
#   Tools/run_simulator.sh                 export, build, install and launch on a booted iPhone simulator
#   Tools/run_simulator.sh --level=1       same, with Godot debug arguments passed through
#   Tools/run_simulator.sh --no-export     reuse build/ios from the last export
#
# The official Godot 4.7.2 iOS template only ships an x86_64 simulator slice, which no
# current (arm64-only) simulator runtime can load, so this links an arm64 simulator library
# built from the Godot 4.7.2 source (scons platform=ios target=template_debug arch=arm64
# simulator=yes) that lives in ~/Library/Application Support/Godot/ios_simulator.
#
# Known limit: Godot's simulator builds only have the OpenGL ES renderer, and the simulator
# runs OpenGL ES through Apple's software rasterizer. Menus are fine; 3D levels take seconds
# per frame (a bit less with rendering/scaling_3d/scale=0.25 set temporarily in project.godot
# before exporting). Use Tools/shot.sh (Mac) or Tools/export_ios.sh (iPhone) for real gameplay.
set -e
cd "$(dirname "$0")/.."
GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
SIMLIB="$HOME/Library/Application Support/Godot/ios_simulator"
BUNDLE=com.faufaufau.cannonduo
DERIVED=build/ios-simulator

EXPORT=1
ARGS=""
for a in "$@"; do
  case "$a" in
    --no-export) EXPORT=0 ;;
    *) ARGS="$ARGS $a" ;;
  esac
done

if [ "$EXPORT" = 1 ]; then
  mkdir -p build/ios
  echo "==> Importing"
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  echo "==> Exporting iOS project (the IPA archive step needs device signing and may fail; the Xcode project is enough)"
  "$GODOT" --headless --path . --export-debug "iOS" build/ios/CannonDuo.xcodeproj 2>&1 | grep -E "^ERROR: (Xcode|Project)" || true
fi

SLICE=build/ios/CannonDuo.xcframework/ios-arm64_x86_64-simulator/libgodot.a
[ -f "$SLICE" ] || { echo "No export at build/ios; run without --no-export"; exit 1; }
echo "==> Adding the arm64 simulator slice"
lipo -create "$SIMLIB/libgodot.ios.template_debug.x86_64.simulator.a" \
             "$SIMLIB/libgodot.ios.template_debug.arm64.simulator.a" -output "$SLICE"

echo "==> Building for the simulator"
xcodebuild -project build/ios/CannonDuo.xcodeproj -scheme CannonDuo -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
APP="$DERIVED/Build/Products/Debug-iphonesimulator/CannonDuo.app"
[ -f "$APP/CannonDuo" ] || { echo "Build failed"; exit 1; }

UDID=$(xcrun simctl list devices booted | grep -oE "[0-9A-F-]{36}" | head -1)
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available | grep -i "iPhone" | grep -oE "[0-9A-F-]{36}" | head -1)
  [ -n "$UDID" ] || { echo "No iPhone simulator; install a runtime with: xcodebuild -downloadPlatform iOS"; exit 1; }
  echo "==> Booting $UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
fi
echo "==> Installing on $UDID"
xcrun simctl install "$UDID" "$APP"
echo "==> Launching"
# shellcheck disable=SC2086
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" ${ARGS:+-- $ARGS}
echo "Screenshot: xcrun simctl io $UDID screenshot /tmp/sim.png"
