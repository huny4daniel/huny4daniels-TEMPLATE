# AGENTS.md

코딩 에이전트(Claude Code, Codex, Copilot 등)가 공통으로 읽는 프로젝트 지침.
사람용 소개는 README.md, 에이전트용 작업 규칙은 이 파일에 둔다.

## 프로젝트 개요

- 목적: {{한 줄 요약}}
- 주요 스택: {{언어 / 프레임워크 / 패키지 매니저}}
- 현재 단계: {{Discovery | Design | Build | Release | Maintain}} — docs/PROCESS.md 참고

## 저장소 구조

- `apps/<name>/` — 실행 단위. 앱끼리 서로 import 하지 않는다.
- `packages/<name>/` — 공유 코드. 앱은 packages만 의존한다.
- `tools/` — 스크립트. 앱 런타임 코드를 두지 않는다.
- `docs/` — 문서. 구조는 docs/README.md 참고.

## 명령어

| 목적 | 명령 |
|---|---|
| 의존성 설치 | `{{INSTALL_COMMAND}}` |
| 실행 | `{{RUN_COMMAND}}` |
| 테스트 전체 | `{{TEST_COMMAND}}` |
| 테스트 단일 | `{{TEST_SINGLE_COMMAND}}` |
| 린트/포맷 | `{{LINT_COMMAND}}` |
| 타입 체크 | `{{TYPECHECK_COMMAND}}` |
| 빌드 | `{{BUILD_COMMAND}}` |

## 작업 규칙

1. 작업 전 관련 문서를 먼저 읽는다: 해당 기능의 `docs/plans/*.md`, 관련 ADR.
2. 규모가 있는 작업은 코드 작성 전에 `docs/templates/plan.md` 형식으로 계획을 세우고 승인받는다.
3. 변경 후 반드시 테스트·린트·타입 체크를 실행하고 결과를 보고한다. 실패를 숨기지 않는다.
4. 한 커밋 = 하나의 논리적 변경. 관련 없는 리팩터링을 섞지 않는다.
5. 구조나 기술 선택을 바꾸는 결정은 `docs/adr/`에 ADR을 추가한다.
6. 사용자에게 보이는 변경은 `CHANGELOG.md`의 `[Unreleased]`에 기록한다.
7. 비밀 값(.env, 키스토어, 토큰)은 커밋하지 않는다.

## 코드 스타일

- {{들여쓰기, 네이밍, import 순서 등 — 린터가 강제하지 않는 것만 적는다}}

## 주의 사항 (Gotchas)

- {{에이전트가 반복해서 틀린 것, 비직관적인 환경 이슈를 발견 즉시 추가}}
