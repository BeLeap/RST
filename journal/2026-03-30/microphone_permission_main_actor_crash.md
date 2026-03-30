# microphone permission main actor crash

## Summary

- Investigated `LOG.TEMP.txt` crash from `2026-03-30 13:50:50 +0900`.
- Confirmed the crash was triggered in `AudioRecorderService.requestPermission()` while handling the microphone permission callback.
- The app was resuming a continuation from `AVCaptureDevice.requestAccess(for: .audio)` on `com.apple.root.default-qos` even though the surrounding service is `@MainActor`.
- Updated the callback to use an explicit `@Sendable` closure and hop back to `MainActor` before resuming the continuation.

## Verification

- Crash log shows `_dispatch_assert_queue_fail` and `_swift_task_checkIsolatedSwift` in `AudioRecorderService.requestPermission()`.
- Local `xcodebuild -project RST.xcodeproj -scheme RST -configuration Debug -derivedDataPath /tmp/RSTDerived build` compiled the Swift sources including `RST/Core/AudioRecorderService.swift` after the change.
- Local build still fails later at link time with an existing linker/configuration problem: `ld: unknown options: -Xlinker -isysroot ...`.

## Relevant files

- `LOG.TEMP.txt`
- `RST/Core/AudioRecorderService.swift`
