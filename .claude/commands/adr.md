---
description: 새 ADR(아키텍처 결정 기록) 작성
argument-hint: <결정 주제>
---

주제: $ARGUMENTS

1. docs/adr/에서 마지막 번호를 확인하고 다음 번호(4자리)를 정한다.
2. 관련 코드·문서를 읽고 맥락을 파악한다. 대안이 정해지지 않았다면 2~3개 대안과 트레이드오프를 먼저 제시하고 선택을 묻는다.
3. .claude/templates/adr.md 형식으로 `docs/adr/NNNN-<kebab-case-제목>.md`를 작성한다. 상태는 Proposed.
4. 이 결정이 기존 ADR을 대체하면 기존 ADR의 상태를 `Superseded by NNNN`으로 바꾼다.
