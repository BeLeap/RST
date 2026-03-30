# Sidebar Files drag & drop WAV import

## 요청
- 사이드바의 `Files` 영역에 WAV 파일을 drag & drop 해서 import할 수 있도록 개선.

## 변경 사항
- `TranscriptStore`에 외부 WAV 파일을 recordings 디렉터리로 복사하는 `importRecording(from:)` 추가.
  - 로컬 파일 여부, `.wav` 확장자 여부, 파일 존재 여부를 명시적으로 검증.
  - 동일 이름 충돌 시 `-2`, `-3` suffix로 안전하게 유니크 이름 생성.
  - 이미 recordings 폴더 내부 파일이면 복사 없이 그대로 반환.
- `RecorderViewModel`에 드롭 처리 흐름 추가.
  - `importDroppedAudio(providers:)`에서 드롭 provider 검증 및 비동기 import 시작.
  - `loadDroppedFileURL`/`loadDroppedFileURLs`로 NSItemProvider에서 파일 URL 추출.
  - `importAudioFiles(from:)`에서 파일별 성공/실패를 수집해 상태 메시지로 노출(에러 숨김 없음).
- `RecorderView`의 `Files` 리스트에 `.onDrop` 추가.
  - 드롭 타깃 하이라이트 오버레이와 "Drop WAV files to import" 안내 문구 표시.

## 메모
- 실패를 조용히 무시하지 않도록 partial failure를 포함한 결과를 status message에 모두 표시.
