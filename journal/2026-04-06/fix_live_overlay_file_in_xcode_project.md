# Fix global overlay file registration in Xcode project

## What changed
- Added `RST/App/LiveChunkOverlayController.swift` to `RST.xcodeproj/project.pbxproj` as:
  - `PBXFileReference`
  - `PBXBuildFile`
  - child of the `App` group
  - member of the target `Sources` build phase

## Why
- CI/xcodebuild could not compile the app reliably when the new Swift file existed on disk but was not registered in the Xcode project graph.

## Notes
- This is a build-graph fix only; runtime behavior of the global live chunk overlay remains unchanged.
