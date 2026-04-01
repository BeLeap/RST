# RST

`RST` is a macOS app for local audio recording, embedded Whisper transcription, and embedded llama.cpp summarization.

## What it does

- Records microphone input into `.wav` files under `~/Library/Application Support/RST/Recordings`
- Runs embedded `whisper.cpp` against those recordings while recording and again on the final file
- Saves transcript files next to the audio as `*-transcript.txt`
- Can summarize the final transcript with embedded `llama.cpp` and saves it as `*-summary.txt`
- Lets you configure separate Whisper models for realtime and final-pass transcription, then auto-download presets into `~/Library/Application Support/RST/Models`
- Exports the selected audio file or transcript to a user-chosen destination
- Lets you reveal the saved audio and transcript in Finder

## Project structure

- [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj)
- [`RST/App/RSTApp.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/App/RSTApp.swift)
- [`RST/Features/RecorderView.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Features/RecorderView.swift)
- [`RST/Core/WhisperTranscriber.swift`](/Users/beleap/pj/github.com/beleap/RST/RST/Core/WhisperTranscriber.swift)

## Requirements

The app links `whisper.cpp` and `llama.cpp` as frameworks, so there is no separate CLI runtime dependency. You can either select a preset Whisper model and let the app download it locally, or point the app at existing `.bin` / `.gguf` files.

## Running

1. Allow `direnv` to load the local Nix shell:

```bash
direnv allow .
```

2. Build the vendored `whisper.cpp` and `llama.cpp` xcframeworks once:

```bash
./scripts/build-whisper-framework.sh
./scripts/build-llama-framework.sh
```

You can also use `just build-whisper`, `just build-llama`, `just build-app`, or `just build`.

3. Open [`RST.xcodeproj`](/Users/beleap/pj/github.com/beleap/RST/RST.xcodeproj/project.pbxproj) in Xcode.
4. Build and run the `RST` target.
5. If macOS blocks the app after moving it, clear quarantine attributes and relaunch:

```bash
xattr -cr /Application/RST.app
```

6. In the sidebar, set:
   - a realtime Whisper model (typically smaller/faster) for live transcript updates while recording
   - a batch Whisper model (typically larger/more accurate) for final transcript generation
   - an embedding `.gguf` model for semantic chunk selection
   - a summary `.gguf` model for the final note generation
   - the transcription language, or `auto`
7. Start recording. The transcript view updates periodically while audio is still being captured.
8. Stop recording for a final pass. After the final transcript completes, the app also generates a summary if both llama models are configured.

## Development Environment

- [`shell.nix`](/Users/beleap/pj/github.com/beleap/RST/shell.nix) provides `cmake`, `ninja`, and `pkg-config`.
- [`.envrc`](/Users/beleap/pj/github.com/beleap/RST/.envrc) uses `direnv` with `use nix`.
- [`Justfile`](/Users/beleap/pj/github.com/beleap/RST/Justfile) wraps the common framework and app build commands.
- [`.github/workflows/build-dmg.yml`](/Users/beleap/pj/github.com/beleap/RST/.github/workflows/build-dmg.yml) builds the Release app and a DMG artifact on macOS runners.

## Notes

- The app uses the microphone and includes `NSMicrophoneUsageDescription` in [`RST/App/Info.plist`](/Users/beleap/pj/github.com/beleap/RST/RST/App/Info.plist).
- Recording stays local.
- Transcription stays local.
