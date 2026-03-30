# GitHub Actions run 23728058764 panel picker main actor

## Summary

- Investigated failed GitHub Actions job `69115564320` from run `23728058764`.
- The `Build macOS app` step failed under Xcode 16.4 because `RST/Core/PanelPicker.swift` wrapped `NSOpenPanel` and `NSSavePanel` from a nonisolated context.
- Marked `PanelPicker` as `@MainActor` so the AppKit panel access matches Swift 6 actor isolation rules.

## Verification

- Fetched the failed Actions log with `gh run view 23728058764 --repo BeLeap/RST --log-failed`.
- Confirmed the CI failure was in `PanelPicker.swift` with main actor isolation errors on `NSOpenPanel` and `NSSavePanel`.
- Local `xcodebuild -project RST.xcodeproj -scheme RST -configuration Release -derivedDataPath build/DerivedData build` no longer reports the `PanelPicker` actor isolation errors.
- Local verification still hits a separate linker failure in this environment that was not present in the fetched CI log.

## Relevant files

- `RST/Core/PanelPicker.swift`
