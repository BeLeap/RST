# Add llama preset selection and download flow

## Summary

- Added `LlamaModelStore` to manage preset llama model downloads with the same UX pattern used for Whisper.
- Added preset pickers for:
  - embedding models
  - summary models
- Kept `Custom Path` support for manual `.gguf` selection.
- Resolved selected llama preset IDs into local downloaded model paths before summary jobs are enqueued.
- Added Nomic-specific embedding input normalization in `LlamaSummaryService` by prefixing chunk text with `search_document:`.

## Presets

- Embedding:
  - `Nomic Embed Text v1.5`
- Summary:
  - `Qwen2.5 0.5B Instruct Q4_K_M`
  - `Qwen2.5 1.5B Instruct Q4_K_M`

## Verification

- `xcodebuild -project RST.xcodeproj -scheme RST -configuration Debug -derivedDataPath /tmp/RSTDerived build`
  - Swift compilation passed, including the new `LlamaModelStore.swift`.
  - Build still fails later at the existing final link step with `ld: unknown options: -Xlinker ...`.
