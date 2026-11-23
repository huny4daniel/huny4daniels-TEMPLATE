---
description: 이슈/작업에 대한 구현 계획을 docs/plans/에 작성
argument-hint: <이슈 번호 또는 작업 설명>
---

작업: $ARGUMENTS

1. 아직 코드를 수정하지 않는다.
2. AGENTS.md, docs/product/PRD.md, docs/architecture/overview.md, 관련 ADR, 관련 코드를 읽고 현재 상태를 파악한다. 이슈 번호라면 `gh issue view`로 내용을 확인한다.
3. 모호한 요구사항이 있으면 먼저 질문한다.
4. docs/templates/plan.md 형식으로 `docs/plans/<이슈번호>-<짧은-이름>.md`를 작성한다. 구현 단계는 각각 검증 가능한 크기로 쪼갠다.
5. 되돌리기 비싼 결정이 필요하면 ADR이 필요하다고 표시한다.
6. 계획 요약을 보여주고 승인을 기다린다.
