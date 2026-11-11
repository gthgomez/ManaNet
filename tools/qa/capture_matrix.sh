#!/usr/bin/env bash
# Capture real ManaNet scenes at a viewport matrix without touching the player's
# save. Requires Godot 4.6.2 and a display (desktop session or xvfb-run).
#
# Usage: tools/qa/capture_matrix.sh [output-root] [scenario ...]
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
out_root="${1:-$repo_root/docs/qa/captures}"
shift || true
scenarios=("$@")
if [ ${#scenarios[@]} -eq 0 ]; then
  scenarios=(menu maps settings cyberdeck_shop cyberdeck_variants game_start game_selected game_details game_placement game_wave_shop game_combat game_boss game_pause end_win end_loss)
fi
if [ -n "${QA_SIZES:-}" ]; then
  # shellcheck disable=SC2206
  sizes=(${QA_SIZES})
else
  sizes=("568x320" "640x360" "800x600" "900x600" "1024x600" "1280x720" "1280x800" "1440x900" "1600x720")
fi
mkdir -p "$out_root"
for size in "${sizes[@]}"; do
  w="${size%x*}"; h="${size#*x}"
  for scenario in "${scenarios[@]}"; do
    profile="$(mktemp -d)"
    shot_dir="$out_root/${size}/${scenario}"
    mkdir -p "$shot_dir"
    env MANANET_PROFILE_PATH="$profile/profile.json" \
        XDG_DATA_HOME="$profile/data" \
        XDG_CONFIG_HOME="$profile/config" \
        XDG_CACHE_HOME="$profile/cache" \
        QA_SHOT_DIR="$shot_dir" \
        QA_SCENARIO="$scenario" \
        "$godot_bin" --path "$repo_root" --resolution "$size" --single-window \
          --position 0,0 --audio-driver Dummy --script tools/qa/capture_screens.gd \
          2>&1 | sed "s|^|[$size/$scenario] |"
    rm -rf "$profile"
  done
done
echo "Captures written to $out_root"
