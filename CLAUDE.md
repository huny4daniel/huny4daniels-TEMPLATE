# CLAUDE.md

공통 지침은 AGENTS.md에 있다. 아래 import로 함께 로드된다.

@AGENTS.md

## Claude Code 전용

- 진행 절차: @docs/PROCESS.md
- 새 기능은 Explore → Plan → Code → Verify → Commit 순서로 진행한다 (docs/PROCESS.md 4단계).
- 작업 단위가 바뀌면 `/clear`로 컨텍스트를 비우고, 이어서 할 내용은 `docs/plans/`의 계획 문서에 남긴다.
- 커스텀 명령: `.claude/commands/` (`/plan`, `/adr`, `/review`)
