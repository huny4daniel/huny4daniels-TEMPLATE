# CLAUDE.md

@AGENTS.md

@.claude/process/PROCESS.md

@docs/STATUS.md

## Claude Code 전용

- 사람이 고를 것(선택지 있는 [질문]·[제안], [승인 요청])은 텍스트 번호 목록 말고 반드시 AskUserQuestion으로 묻는다. 추천안은 첫 선택지에 "(추천)", 질문 1~4개·선택지 2~4개. 자유 서술 질문과 [요청]만 텍스트로 끝낸다.
- 작업 단위가 바뀌면 `/clear`를 권한다. STATUS.md와 계획 문서가 다음 세션의 기억이다.
- 사용자가 다른 요청으로 세션을 시작했다면 그 요청을 먼저 처리하고, 현재 위치 브리핑은 짧게 덧붙인다(응답 꼬리표 규칙은 PROCESS.md 협업 규칙 1).
