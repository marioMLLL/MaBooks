#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
task_bin_dir="$(swift build -c release --show-bin-path)"
task_app_dir="$PWD/dist/WeReadMac.app"
mkdir -p "$task_app_dir/Contents/MacOS" "$task_app_dir/Contents/Resources"
cp "$task_bin_dir/WeReadMac" "$task_app_dir/Contents/MacOS/WeReadMac"
cp packaging/Info.plist "$task_app_dir/Contents/Info.plist"
codesign --force --sign - "$task_app_dir"
codesign --verify --deep --strict "$task_app_dir"
echo "Built: $task_app_dir"
