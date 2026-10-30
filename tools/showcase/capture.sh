#!/usr/bin/env bash
# Capture real Godot scenes without reading/writing the operator's game save.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
case "$("$godot_bin" --version)" in
  4.6.2.*) ;;
  *) echo 'Capture requires the pinned Godot 4.6.2 executable.' >&2; exit 2 ;;
esac
command -v ffmpeg >/dev/null
capture_tmp="$(mktemp -d)"
trap 'rm -rf "$capture_tmp"' EXIT
export XDG_DATA_HOME="$capture_tmp/data" XDG_CONFIG_HOME="$capture_tmp/config" XDG_CACHE_HOME="$capture_tmp/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export SHOWCASE_OUTPUT="$repo_root/docs/showcase"
mkdir -p "$SHOWCASE_OUTPUT"
"$godot_bin" --headless --editor --path "$repo_root" --import
# A graphical display (desktop session or isolated Xorg/Xvfb) is required here.
"$godot_bin" --path "$repo_root" --resolution 900x600 --single-window --borderless \
  --audio-driver Dummy --write-movie "$capture_tmp/gameplay.avi" --fixed-fps 30 \
  --script tools/showcase/capture.gd
ffmpeg -hide_banner -loglevel error -y -i "$capture_tmp/gameplay.avi" -an \
  -c:v libx264 -preset fast -crf 25 -pix_fmt yuv420p -movflags +faststart \
  "$SHOWCASE_OUTPUT/gameplay.mp4"
ffmpeg -hide_banner -loglevel error -y -ss 8 -t 10 -i "$SHOWCASE_OUTPUT/gameplay.mp4" \
  -filter_complex 'fps=8,scale=600:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer' \
  -loop 0 "$SHOWCASE_OUTPUT/gameplay-preview.gif"
