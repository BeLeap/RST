set shell := ["zsh", "-euo", "pipefail", "-c"]

derived_data := "/tmp/RSTDerived"

# Show available recipes.
default:
  just --list

# Build the vendored whisper.cpp xcframework.
build-whisper:
  ./scripts/build-whisper-framework.sh

# Build the vendored llama.cpp xcframework.
build-llama:
  ./scripts/build-llama-framework.sh

# Build the macOS app with xcodebuild.
build-app:
  env -u LD xcodebuild -project RST.xcodeproj -scheme RST -configuration Debug -derivedDataPath {{derived_data}} build

# Build the embedded Whisper and llama frameworks and then the app.
build: build-whisper build-llama build-app
