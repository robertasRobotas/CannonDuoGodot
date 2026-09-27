#!/bin/sh
# Run a level on the Mac and save a screenshot: Tools/shot.sh LEVEL SECONDS OUT.png [POWER,YAW,PITCH]
cd "$(dirname "$0")/.."
GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
FIRE=""
[ -n "$4" ] && FIRE="--fire=$4"
"$GODOT" --path . --resolution 590x1278 -- "--shot=$1,$2,$3" $FIRE 2>&1 | grep -i -E "script error|at: " | sort -u
