# RST

`RST` is a macOS app for local audio recording and embedded Whisper transcription.

## What it does

- Records microphone input into `.wav` files under `~/Library/Application Support/RST/Recordings`
- Runs embedded `whisper.cpp` against those recordings while recording and again on the final file
- Saves transcript files next to the audio as `*-transcript.txt`
- Exports the selected audio file or transcript to a user-chosen destination
- Lets you reveal the saved audio and transcript in Finder

## Project structure

- [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj)
- [`RST/App/RSTApp.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/App/RSTApp.swift)
- [`RST/Features/RecorderView.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Features/RecorderView.swift)
- [`RST/Core/WhisperTranscriber.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Core/WhisperTranscriber.swift)

## Requirements

You need a local Whisper model file in `.bin` format. The app links `whisper.cpp` as a framework, so there is no separate `whisper-cli` runtime dependency.

## Running

1. Open [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj) in Xcode.
2. Build and run the `RST` target.
3. Build the vendored `whisper.cpp` xcframework once:

```bash
./scripts/build-whisper-framework.sh
```

4. In the sidebar, set:
   - the full path to your `.bin` model
   - the transcription language, or `auto`
5. Start recording. The transcript view updates periodically while audio is still being captured.
6. Stop recording for a final pass, or export the selected `.wav` / `.txt` files from the sidebar.

## Notes

- The app uses the microphone and includes `NSMicrophoneUsageDescription` in [`RST/App/Info.plist`](/Users/beleap/pj/github.com/beleap/RST/RST/App/Info.plist).
- Recording stays local.
- Transcription stays local.
