# macOS local whisper app

## Summary

- Created a new `RST.xcodeproj` macOS SwiftUI application from an empty repository.
- Implemented local microphone recording with `AVAudioRecorder`.
- Vendored `whisper.cpp` source into `Vendor/whisper.cpp`.
- Switched local transcription design from `whisper-cli` process execution to embedded `whisper.cpp` framework usage.
- Reduced the UI to the model path and language because there is no longer an external CLI path.
- Added periodic live transcription during recording by repeatedly transcribing the in-progress WAV file.
- Added export actions for the selected recording and transcript.
- Added a helper build script for the embedded `whisper.cpp` xcframework.
- Added `shell.nix` and `.envrc` so the build toolchain can be loaded through `direnv` and Nix.
- Added a Whisper model picker that can auto-download preset `.bin` files into `~/Library/Application Support/RST/Models` while still allowing a custom model path.
- Stored recordings and transcripts in `~/Library/Application Support/RST/Recordings`.

## Constraints

- Xcode is now active in the environment.
- Local Whisper model files were not installed in this environment.
- Runtime verification still depends on entering the Nix shell so `cmake` is available for `whisper.cpp` framework generation.

## Relevant files

- `RST.xcodeproj/project.pbxproj`
- `RST/App/Info.plist`
- `RST/App/RSTApp.swift`
- `RST/Features/RecorderView.swift`
- `RST/Features/RecorderViewModel.swift`
- `RST/Core/AudioRecorderService.swift`
- `RST/Core/WhisperTranscriber.swift`
- `RST/Core/WaveDecoder.swift`
- `Vendor/whisper.cpp`
- `RST/Core/TranscriptStore.swift`
