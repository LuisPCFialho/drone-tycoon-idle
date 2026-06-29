#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT:-/c/Apps/Godot/Godot_v4.6.2-stable_win64_console.exe}"
export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
SDK="${ANDROID_SDK:-/c/Users/$USER/AppData/Local/Android/Sdk}"
export PATH="$JAVA_HOME/bin:$SDK/build-tools/35.0.1:$PATH"
mkdir -p export
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Android" "export/DroneTycoon.apk"
echo "APK -> export/DroneTycoon.apk"
