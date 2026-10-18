#!/usr/bin/env bash
# Builds assets/snaptty.icns from the 1024x1024 assets/snaptty.png.
#
# Usage: scripts/make-icon.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_png="${root}/assets/snaptty.png"
output="${root}/assets/snaptty.icns"
iconset="$(mktemp -d)/snaptty.iconset"
trap 'rm -rf "$(dirname "$iconset")"' EXIT
mkdir -p "$iconset"

for base in 16 32 128 256 512; do
  sips -z "$base" "$base" "$source_png" --out "${iconset}/icon_${base}x${base}.png" >/dev/null
  double=$((base * 2))
  sips -z "$double" "$double" "$source_png" --out "${iconset}/icon_${base}x${base}@2x.png" >/dev/null
done

iconutil -c icns "$iconset" -o "$output"
echo "wrote ${output}"
