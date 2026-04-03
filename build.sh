#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="VoiceInput"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
EXECUTABLE="$EXECUTABLE_DIR/$APP_NAME"
SIGN_IDENTITY="${SIGN_IDENTITY:-VoiceInput Local Code Signing}"
WHISPER_RESOURCES_DIR="$RESOURCES_DIR/WhisperCLI"
MODELS_RESOURCES_DIR="$RESOURCES_DIR/Models"

rm -rf "$APP_DIR"
mkdir -p "$EXECUTABLE_DIR" "$RESOURCES_DIR" "$WHISPER_RESOURCES_DIR" "$MODELS_RESOURCES_DIR" "$BUILD_DIR/clang-module-cache" "$BUILD_DIR/swift-module-cache"

cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

if ! clang --version >/dev/null 2>&1; then
  echo "System clang is broken on this Mac. Reinstall Command Line Tools or install full Xcode first."
  echo "Quick checks:"
  echo "  xcode-select --install"
  echo "  sudo rm -rf /Library/Developer/CommandLineTools"
  echo "  xcode-select --install"
  exit 1
fi

CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-module-cache" \
SWIFT_MODULE_CACHE_PATH="$BUILD_DIR/swift-module-cache" \
swiftc \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$EXECUTABLE" \
  -framework Cocoa \
  -framework AVFoundation \
  -framework Speech \
  -framework ApplicationServices \
  -framework AudioToolbox

cp "$ROOT_DIR/Vendor/whisper.cpp/build/bin/whisper-cli" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/src/libwhisper.1.dylib" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/ggml/src/libggml.0.dylib" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/ggml/src/libggml-cpu.0.dylib" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/ggml/src/libggml-base.0.dylib" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/ggml/src/ggml-blas/libggml-blas.0.dylib" "$WHISPER_RESOURCES_DIR/"
cp "$ROOT_DIR/Vendor/whisper.cpp/build/ggml/src/ggml-metal/libggml-metal.0.dylib" "$WHISPER_RESOURCES_DIR/"
chmod +x "$WHISPER_RESOURCES_DIR/whisper-cli"

for binary in \
  "$WHISPER_RESOURCES_DIR/whisper-cli" \
  "$WHISPER_RESOURCES_DIR/libwhisper.1.dylib" \
  "$WHISPER_RESOURCES_DIR/libggml.0.dylib" \
  "$WHISPER_RESOURCES_DIR/libggml-cpu.0.dylib" \
  "$WHISPER_RESOURCES_DIR/libggml-base.0.dylib" \
  "$WHISPER_RESOURCES_DIR/libggml-blas.0.dylib" \
  "$WHISPER_RESOURCES_DIR/libggml-metal.0.dylib"; do
  install_name_tool -add_rpath "@executable_path" "$binary" 2>/dev/null || true
  install_name_tool -add_rpath "@loader_path" "$binary" 2>/dev/null || true
done

cp "$ROOT_DIR/Models/ggml-model-whisper-base.bin" "$MODELS_RESOURCES_DIR/"
cp "$ROOT_DIR/Models/ggml-model-whisper-small.bin" "$MODELS_RESOURCES_DIR/"

if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$SIGN_IDENTITY"; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
  echo "Signed with identity: $SIGN_IDENTITY"
else
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
  echo "Signed ad-hoc. To keep permissions stable across rebuilds, run ./setup_local_codesign.sh once."
fi

echo "Built app: $APP_DIR"
