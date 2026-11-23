---
description: 현재 변경 사항을 Definition of Done 기준으로 점검
---

1. `git diff`(스테이징 포함)와 관련 계획 문서(docs/plans/)를 읽는다.
2. 다음을 점검하고 항목별로 통과/미통과와 근거를 보고한다:
   - 계획 문서의 수용 기준 충족 여부
   - 버그·엣지 케이스·오류 처리 누락
   - 테스트 추가 여부, 그리고 AGENTS.md의 테스트·린트·타입 체크 명령 실제 실행 결과
   - 앱 간 직접 import, packages → apps 의존 등 구조 규칙 위반
   - ADR / CHANGELOG / README 갱신 필요 여부
   - 비밀 값 포함 여부
3. 수정은 하지 않고 발견 사항만 심각도 순으로 나열한다.
