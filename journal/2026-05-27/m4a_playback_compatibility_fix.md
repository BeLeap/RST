# M4A playback compatibility fix

## Context
사용자 보고: 변환된 M4A가 일부 환경에서 재생되지 않음.

## Changes
- `AudioFileTranscoder.exportCompressedAudio` AAC 출력 샘플레이트를 `16_000`에서 `44_100`으로 조정.
- AAC 인코딩 품질 키(`AVEncoderAudioQualityKey`)를 추가해 출력 안정성을 강화.

## Why
- 16 kHz AAC는 기술적으로 가능하지만 일부 플레이어/워크플로우에서 호환성 이슈가 발생할 수 있어, 범용 재생기 호환성이 더 높은 44.1 kHz를 기본값으로 설정.
