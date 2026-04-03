#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="VoiceInput"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"

"$ROOT_DIR/build.sh"

if [ ! -d "$SOURCE_APP" ]; then
  echo "Build did not produce $SOURCE_APP"
  exit 1
fi

ditto "$SOURCE_APP" "$TARGET_APP"
echo "Installed app: $TARGET_APP"
