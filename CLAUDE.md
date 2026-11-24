# CLAUDE.md

@AGENTS.md

@docs/PROCESS.md

@docs/STATUS.md

## Claude Code 전용

- 선택지를 물을 때는 가능하면 AskUserQuestion(선택지 UI)을 쓴다.
- 작업 단위가 바뀌면 `/clear`를 권한다. STATUS.md와 계획 문서가 다음 세션의 기억이다.
- 사용자가 다른 요청으로 세션을 시작했다면 그 요청을 먼저 처리하고, 현재 위치 브리핑은 짧게 덧붙인다.
