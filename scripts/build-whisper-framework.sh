#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/../Vendor/whisper.cpp"
./build-xcframework.sh
