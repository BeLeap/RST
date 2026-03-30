set shell := ["zsh", "-euo", "pipefail", "-c"]

derived_data := "/tmp/RSTDerived"

# Show available recipes.
default:
  just --list

# Build the vendored whisper.cpp xcframework.
build-whisper:
  ./scripts/build-whisper-framework.sh

# Build the macOS app with xcodebuild.
build-app:
  xcodebuild -project RST.xcodeproj -scheme RST -configuration Debug -derivedDataPath {{derived_data}} build

# Build the embedded Whisper framework and then the app.
build: build-whisper build-app
