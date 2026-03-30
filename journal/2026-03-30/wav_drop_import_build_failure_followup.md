# WAV drop import build failure follow-up

## 배경
- 이전 WAV drag & drop 구현 이후 CI/Xcode 16.4 Release 빌드 실패 리포트가 들어와 후속 수정 진행.

## 수정 내용
- `RecorderViewModel.importDroppedAudio`의 비동기 실행 블록을 `Task { @MainActor in ... }`로 명시해 actor 격리 관련 컴파일 문제 가능성을 줄임.
- 드롭 payload 해석 로직을 정리:
  - 기존: `TaskGroup` 내부에서 오류를 `return nil`로 삼켜 버리는 형태.
  - 변경: 순차 로딩으로 단순화하고 `(urls, errors)` 튜플을 반환.
  - 결과적으로 드롭 단계의 에러도 `statusMessage`로 명시적으로 표면화.
- `importAudioFiles(from:preflightErrors:)`를 도입해
  - 드롭 URL 해석 실패(preflight)와 파일 복사 실패(import)를 한 흐름으로 합산 보고.
  - 빈 URL 입력 시에도 상세 에러를 포함해 실패 원인을 UI에 명확히 전달.

## 메모
- 사용자 커스텀 지침(에러 숨김 금지)에 맞춰, 드롭 단계 실패를 더 이상 무시하지 않도록 조정.
