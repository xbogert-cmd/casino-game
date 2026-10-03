#!/bin/zsh
# Runs the game, saves a screenshot, quits. Usage: tools/shot.sh out.png [--stage=table] [--cam=x,y,z,lx,ly,lz]
# Gives up after 90 seconds so a script error can't leave a window hanging.
cd "$(dirname "$0")/.."
out="$1"; shift
/opt/homebrew/bin/godot --path . -- --shot="$out" "$@" 2>&1 | grep -vE '^(Godot|Metal|Vulkan|$)' &
sleep 1
pid=$(pgrep -f "godot --path . -- --shot=$out")
( sleep 90; kill $pid 2>/dev/null ) &
wait %1
