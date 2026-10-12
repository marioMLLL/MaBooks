#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_developer_dir="$(xcode-select -p)"
task_frameworks="$task_developer_dir/Library/Developer/Frameworks"
if [[ "$task_developer_dir" == */CommandLineTools && -d "$task_frameworks/Testing.framework" ]]; then
    # Some CLT installations include Testing.framework without SwiftPM search paths.
    swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$task_frameworks" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -F -Xlinker "$task_frameworks" \
        -Xlinker -rpath -Xlinker "$task_frameworks"
else
    swift test --disable-xctest
fi
