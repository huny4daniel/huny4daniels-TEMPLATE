# 0001. 아키텍처 결정을 ADR로 기록한다

- 상태: Accepted
- 날짜: YYYY-MM-DD

## 맥락 (Context)

프로젝트에서 내린 구조적 결정의 이유가 시간이 지나면 잊히고, 코딩 에이전트는 매 세션 맥락 없이 시작한다. 결정과 그 근거를 저장소 안에 남겨야 사람과 에이전트 모두 같은 전제에서 작업할 수 있다.

## 결정 (Decision)

Michael Nygard가 제안한 ADR 형식으로 되돌리기 비싼 결정을 `docs/adr/NNNN-<제목>.md`에 기록한다. 템플릿은 `docs/templates/adr.md`를 쓴다.

## 결과 (Consequences)

- 결정의 근거를 추적할 수 있다.
- 승인된 ADR은 수정하지 않고, 바뀌면 새 ADR을 쓰고 이전 것을 Superseded로 표시한다.
- 결정마다 짧은 문서 작성 비용이 든다.
