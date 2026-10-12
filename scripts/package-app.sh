#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
task_bin_dir="$(swift build -c release --show-bin-path)"
task_app_dir="$PWD/dist/MaBooks.app"
mkdir -p "$task_app_dir/Contents/MacOS" "$task_app_dir/Contents/Resources"
cp "$task_bin_dir/MaBooks" "$task_app_dir/Contents/MacOS/MaBooks"
for task_resource_bundle in "$task_bin_dir"/*.bundle; do
    [[ -d "$task_resource_bundle" ]] || continue
    cp -R "$task_resource_bundle" "$task_app_dir/Contents/Resources/"
done
test -s "$task_app_dir/Contents/Resources/MaBooks_MaBooks.bundle/sakura-reading.png"
cp packaging/Info.plist "$task_app_dir/Contents/Info.plist"
codesign --force --sign - "$task_app_dir"
codesign --verify --deep --strict "$task_app_dir"
echo "Built: $task_app_dir"
