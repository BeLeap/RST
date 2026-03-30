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
- Stored recordings and transcripts in `~/Library/Application Support/RST/Recordings`.

## Constraints

- The environment only has Command Line Tools active, so `xcodebuild` is not available here.
- Full Xcode is still not active in this environment, so `build-xcframework.sh` could not be validated here.
- Local Whisper model files were not installed in this environment.
- Because of that, runtime verification could only cover source changes and static review, not a full app build or end-to-end transcription run.

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
