#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_icon_source="$PWD/Sources/MaBooks/Resources/AppIcon.png"
task_icon_workdir="$(mktemp -d)"
trap 'rm -rf "$task_icon_workdir"' EXIT
task_iconset="$task_icon_workdir/MaBooks.iconset"
mkdir -p "$task_iconset" "$PWD/dist"
test -s "$task_icon_source"
for task_icon_size in 16 32 128 256 512; do
    sips --resampleHeightWidth "$task_icon_size" "$task_icon_size" "$task_icon_source" \
        --out "$task_iconset/icon_${task_icon_size}x${task_icon_size}.png" >/dev/null
    task_retina_size=$((task_icon_size * 2))
    sips --resampleHeightWidth "$task_retina_size" "$task_retina_size" "$task_icon_source" \
        --out "$task_iconset/icon_${task_icon_size}x${task_icon_size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$PWD/dist/MaBooks.icns" "$task_iconset"
echo "Built: $PWD/dist/MaBooks.icns"
