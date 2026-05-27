# M4A empty file investigation and converter EOS fix

## Context
- 사용자 제공 Base64 샘플을 디코드해 확인한 결과, 파일이 `ftyp` + `moov`만 있고 `mdat`가 없는 빈 M4A(오디오 샘플 누락) 형태였음.
- 기존 변환 루프는 입력 버퍼 단위 반복 구조였고, 컨버터 flush/end-of-stream 처리 경로가 불명확해 AAC 샘플 테이블이 비는 케이스를 유발할 수 있었음.

## Changes
- `AudioFileTranscoder.transcodeAudio`를 단일 스트리밍 변환 루프로 정리.
- `AVAudioConverter` input block에서 EOF 시 `.endOfStream`을 명시적으로 전달하도록 수정.
- 변환 루프를 `.endOfStream` 수신 시점까지 지속하여 컨버터 내부 버퍼를 끝까지 배출하도록 수정.
- 입력 파일 read 오류를 별도 변수로 포착 후 즉시 throw하여 오류를 숨기지 않도록 처리.

## Why
- AAC 컨테이너에 메타데이터만 있고 실제 오디오 chunk(`mdat`)가 없는 손상성 결과를 방지.
- 오류를 명시적으로 노출해 디버깅 가능성을 높임.
