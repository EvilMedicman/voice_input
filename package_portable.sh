#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="VoiceInput"
BUILD_DIR="$ROOT_DIR/build"
PORTABLE_DIR="$BUILD_DIR/portable/$APP_NAME for Friend"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
README_FILE="$PORTABLE_DIR/README.txt"

"$ROOT_DIR/build.sh"

rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR"
ditto "$APP_DIR" "$PORTABLE_DIR/$APP_NAME.app"

cat > "$README_FILE" <<'EOF'
VoiceInput for macOS

How to start:
1. Copy VoiceInput.app into Applications.
2. Open the app.
3. If macOS warns about security, open System Settings > Privacy & Security and click Open Anyway.
4. Allow Microphone access.
5. If you want automatic typing, also allow Accessibility.

The Base and Small models are already bundled inside the app.
EOF

echo "Portable folder prepared: $PORTABLE_DIR"
