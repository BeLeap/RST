#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
VENDOR_DIR="$ROOT_DIR/Vendor/whisper.cpp"
BUILD_DIR="$VENDOR_DIR/build-macos-only"
OUTPUT_DIR="$VENDOR_DIR/build-apple"
HEADERS_DIR="$OUTPUT_DIR/headers"
COMBINED_LIB="$OUTPUT_DIR/libwhisper-combined.a"
FRAMEWORK_OUT="$OUTPUT_DIR/whisper.xcframework"
FRAMEWORK_DIR="$OUTPUT_DIR/whisper.framework"
FRAMEWORK_HEADERS_DIR="$FRAMEWORK_DIR/Versions/A/Headers"
FRAMEWORK_MODULES_DIR="$FRAMEWORK_DIR/Versions/A/Modules"
FRAMEWORK_RESOURCES_DIR="$FRAMEWORK_DIR/Versions/A/Resources"
FRAMEWORK_BINARY="$FRAMEWORK_DIR/Versions/A/whisper"
SUBMODULE_PATH="${VENDOR_DIR#$ROOT_DIR/}"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CLANG="$(xcrun --sdk macosx --find clang)"
CLANGXX="$(xcrun --sdk macosx --find clang++)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

ensure_vendor_checkout() {
  if [[ -f "$VENDOR_DIR/CMakeLists.txt" ]]; then
    return
  fi

  if [[ -e "$ROOT_DIR/.gitmodules" ]] && command -v git >/dev/null 2>&1; then
    echo "Missing $SUBMODULE_PATH, attempting to initialize submodule"
    git -C "$ROOT_DIR" submodule update --init --recursive "$SUBMODULE_PATH"
  fi

  if [[ ! -f "$VENDOR_DIR/CMakeLists.txt" ]]; then
    echo "Expected vendor source at $VENDOR_DIR but it is missing." >&2
    echo "Ensure the repository is checked out with submodules." >&2
    exit 1
  fi
}

ensure_vendor_checkout

cd "$VENDOR_DIR"
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$HEADERS_DIR"

cmake -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3 \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS_DEFAULT=ON \
  -DGGML_METAL_USE_BF16=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DWHISPER_COREML=ON \
  -DWHISPER_COREML_ALLOW_FALLBACK=ON \
  -S .

cmake --build "$BUILD_DIR"

libtool -static -o "$COMBINED_LIB" \
  "$BUILD_DIR/src/libwhisper.a" \
  "$BUILD_DIR/ggml/src/libggml.a" \
  "$BUILD_DIR/ggml/src/libggml-base.a" \
  "$BUILD_DIR/ggml/src/libggml-cpu.a" \
  "$BUILD_DIR/ggml/src/ggml-metal/libggml-metal.a" \
  "$BUILD_DIR/ggml/src/ggml-blas/libggml-blas.a" \
  "$BUILD_DIR/src/libwhisper.coreml.a"

cp include/whisper.h "$HEADERS_DIR/"
cp ggml/include/ggml.h "$HEADERS_DIR/"
cp ggml/include/ggml-alloc.h "$HEADERS_DIR/"
cp ggml/include/ggml-backend.h "$HEADERS_DIR/"
cp ggml/include/ggml-metal.h "$HEADERS_DIR/"
cp ggml/include/ggml-cpu.h "$HEADERS_DIR/"
cp ggml/include/ggml-blas.h "$HEADERS_DIR/"
cp ggml/include/gguf.h "$HEADERS_DIR/"

cat > "$HEADERS_DIR/module.modulemap" <<'EOF'
framework module whisper {
  header "whisper.h"
  header "ggml.h"
  header "ggml-alloc.h"
  header "ggml-backend.h"
  header "ggml-metal.h"
  header "ggml-cpu.h"
  header "ggml-blas.h"
  header "gguf.h"

  link "c++"
  link framework "Accelerate"
  link framework "Metal"
  link framework "Foundation"
  link framework "CoreML"

  export *
}
EOF

mkdir -p "$FRAMEWORK_HEADERS_DIR" "$FRAMEWORK_MODULES_DIR" "$FRAMEWORK_RESOURCES_DIR"
ln -sf A "$FRAMEWORK_DIR/Versions/Current"
ln -sf Versions/Current/Headers "$FRAMEWORK_DIR/Headers"
ln -sf Versions/Current/Modules "$FRAMEWORK_DIR/Modules"
ln -sf Versions/Current/Resources "$FRAMEWORK_DIR/Resources"
ln -sf Versions/Current/whisper "$FRAMEWORK_DIR/whisper"

cp "$HEADERS_DIR/"* "$FRAMEWORK_HEADERS_DIR/"
cp "$HEADERS_DIR/module.modulemap" "$FRAMEWORK_MODULES_DIR/module.modulemap"

cat > "$FRAMEWORK_RESOURCES_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>whisper</string>
  <key>CFBundleIdentifier</key>
  <string>org.ggml.whisper</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>whisper</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>MinimumOSVersion</key>
  <string>13.3</string>
  <key>DTPlatformName</key>
  <string>macosx</string>
</dict>
</plist>
EOF

xcrun --sdk macosx clang++ -dynamiclib \
  -isysroot "$SDKROOT" \
  -arch arm64 -arch x86_64 \
  -mmacosx-version-min=13.3 \
  -Wl,-force_load,"$COMBINED_LIB" \
  -framework Foundation \
  -framework Metal \
  -framework Accelerate \
  -framework CoreML \
  -install_name "@rpath/whisper.framework/Versions/Current/whisper" \
  -o "$FRAMEWORK_BINARY"

xcodebuild -create-xcframework \
  -framework "$FRAMEWORK_DIR" \
  -output "$FRAMEWORK_OUT"

echo "Built $FRAMEWORK_OUT"
