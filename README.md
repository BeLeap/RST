# RST

`RST` is a macOS app for local audio recording and local Whisper transcription.

## What it does

- Records microphone input into `.wav` files under `~/Library/Application Support/RST/Recordings`
- Runs local `whisper-cli` against those recordings
- Saves transcript files next to the audio as `*-transcript.txt` and `*-transcript.json`
- Lets you reveal the saved audio and transcript in Finder

## Project structure

- [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj)
- [`RST/App/RSTApp.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/App/RSTApp.swift)
- [`RST/Features/RecorderView.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Features/RecorderView.swift)
- [`RST/Core/WhisperCLITranscriber.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Core/WhisperCLITranscriber.swift)

## Requirements

You need a local `whisper-cli` executable and a local Whisper model file in `.bin` format. The app does not download either one for you.

Typical `whisper.cpp` usage, per upstream docs, looks like this:

```bash
whisper-cli -m /path/to/model.bin -f /path/to/audio.wav -l auto -otxt -oj -of /path/to/output-base
```

## Running

1. Open [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj) in Xcode.
2. Build and run the `RST` target.
3. In the sidebar, set:
   - the full path to `whisper-cli`
   - the full path to your `.bin` model
   - the transcription language, or `auto`
4. Start recording, stop recording, then transcribe.

## Notes

- The app uses the microphone and includes `NSMicrophoneUsageDescription` in [`RST/App/Info.plist`](/Users/beleap/pj/github.com/beleap/RST/RST/App/Info.plist).
- Recording stays local.
- Transcription stays local.
