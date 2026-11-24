# huny4daniels-TEMPLATE

사람과 코딩 에이전트(Claude Code)가 **역할을 나눠** 아이디어를 제품으로 만드는 프로젝트 템플릿.
폴더 구조, 진행 절차 문서, 에이전트 지침, 그리고 에이전트가 잊어도 항상 동작하는 **결정론적 안전장치(훅)**를 한 묶음으로 제공한다.

> 이 파일은 템플릿 저장소 소개용이다(템플릿 전용, 새 프로젝트로 복사되지 않음).
> 루트의 [README.md](../README.md)는 새 프로젝트가 채워 쓸 README 뼈대다.

---

## 왜 만들었나

코딩 에이전트에게 일을 맡기면 세 가지 문제가 반복된다.

| 문제 | 증상 | 이 템플릿의 대응 |
|---|---|---|
| **기억이 끊긴다** | 세션이 바뀌면 지난 결정·진행 상황을 다시 설명해야 한다 | `docs/STATUS.md`·계획 문서를 세션 간 기억으로 쓰고, 세션 시작 시 자동 로드 |
| **지시를 잊는다** | "테스트 돌려라", "main에 바로 push 하지 마라"를 가끔 어긴다 | 지켜야 하는 것은 문서가 아니라 **훅**으로 강제 |
| **어디까지 맡길지 모호하다** | 사소한 것까지 묻거나, 반대로 되돌리기 어려운 일을 혼자 한다 | 사람 승인이 필요한 **게이트**와 자율 영역을 표로 고정 |

## 설계 원칙

1. **확률적 지시와 결정론적 장치를 나눈다.** `AGENTS.md`·`PROCESS.md`는 에이전트가 지키려고 노력하는 규칙이고, `.claude/hooks/`는 에이전트가 잊어도 항상 실행되는 장치다. 장치로 강제할 수 있는 것은 지시문에 반복하지 않는다.
2. **컨텍스트는 필요한 만큼만.** 세션마다 자동 로드되는 것은 핵심 규칙·목차·현재 상태뿐이고, 단계별 상세 절차(`docs/process/`)는 그 단계에 들어갈 때만 읽는다.
3. **사람은 결정, 에이전트는 진행.** 사람은 Product Owner로서 선택·승인·사람만 할 수 있는 일을 맡고, 에이전트는 질문으로 요구를 끌어내고 다음 행동을 먼저 제안한다. 모든 응답은 [질문] / [제안] / [승인 요청] / [요청] 중 하나로 끝난다.
4. **막기보다 확인.** 위험 명령은 차단하지 않고 확인 창을 띄운다(ask). 기계적으로 판단 가능한 위반(CI 실패 상태의 PR 병합)만 거부한다(deny).
5. **검증 루프는 끝나야 한다.** 자동 검사 실패로 응답 종료를 막되, 같은 실패는 한 번만 막고 훅으로 이어진 응답에서는 경고만 띄워 무한 반복을 막는다.
6. **업계 관행을 엮는다, 새로 발명하지 않는다.** Lean Canvas, PRD, ADR(Nygard), C4, Walking Skeleton, GitHub Flow, SemVer, Keep a Changelog, Explore→Plan→Code→Commit.

## 구성

```
.
├── AGENTS.md              에이전트 공용 지침 (Claude Code·Codex·Copilot)
├── CLAUDE.md              Claude 전용 — AGENTS.md·PROCESS.md·STATUS.md를 import
├── apps/ packages/ tools/ 모노레포 구조 (apps → packages 단방향 의존)
├── docs/
│   ├── PROCESS.md         진행 절차 핵심 규칙·목차 (자동 로드)
│   ├── STATUS.md          현재 단계·다음 할 일·결정·가정 (자동 로드, 세션 간 기억)
│   ├── process/           단계별 상세 절차 (필요할 때만 읽음)
│   ├── templates/         PRD·ADR·계획·회고 등 문서 템플릿
│   └── product/ architecture/ adr/ plans/ runbooks/ postmortems/ retros/
├── .claude/
│   ├── commands/          /kickoff /next /plan /adr /review /fix /wrap
│   ├── hooks/             guard.sh · check-file.sh · check-turn.sh · checks.env
│   └── settings.json      훅 등록, 비밀 파일 읽기 차단
└── .github/               CI 뼈대, 이슈·PR 템플릿
```

## 진행 흐름

```
0 초기화 → 1 아이디어·PRD → 2 설계 → 3 계획 → [4 구현 ⇄ 5 검증] → 6 릴리즈 → 7 회고
             ↑ 큰 새 기능                 ↑________ 다음 마일스톤 ____________|
             |____________ 유지보수 모드 (버그 분류 → 수정 → PATCH) ←_______|
```

| 단계 | 사람이 하는 일 | 게이트 |
|---|---|---|
| 1 아이디어·PRD | 인터뷰에 답하고 범위 선택 | MVP 범위·비목표 확정 |
| 2 설계 | 스택·개발 환경·릴리즈 방식 선택 | 기술 선택 ADR 승인 |
| 3 계획 | 마일스톤·이슈 확인 | 이슈 분해 승인 |
| 4~5 구현·검증 | 이슈별 계획 승인, 실기기·체감 확인 | DoD, 사람 확인 |
| 6 릴리즈 | 버전·배포 승인 | 태그·릴리즈 |

상세: [docs/PROCESS.md](../docs/PROCESS.md)

## 안전장치

| 시점 | 장치 | 동작 |
|---|---|---|
| 셸 명령 직전 | `guard.sh` (PreToolUse) | main/태그/force push, PR 병합, 릴리즈, 재귀 삭제, 배포, 외부 API 쓰기 → 확인 창. PR 병합은 `gh pr checks`로 CI를 조회해 실패·진행 중이면 거부 |
| 파일 수정 직후 | `check-file.sh` (PostToolUse) | 포매터·린터 실행, 오류면 에이전트에게 되돌림 |
| 응답 종료 시 | `check-turn.sh` (Stop) | 코드가 바뀌었으면 린트·타입 체크·테스트, 실패면 종료를 막고 고치게 함 (같은 상태 재검사 생략, 반복 방지) |
| 항상 | `settings.json` deny | `.env`·키스토어·인증서를 Read 도구로 읽지 못하게 함 |
| PR | CI | 설치·린트·타입 체크·테스트·빌드 |

검사 명령은 `.claude/hooks/checks.env` 한 곳에서 정하고, `AGENTS.md` 명령 표·CI와 같게 유지한다. 템플릿 상태에서는 비어 있어 꺼져 있다.

알려진 한계는 [로드맵](ROADMAP.md)에 정리했다 (패턴 판정의 우회 가능성, 셸 경유 비밀 파일 읽기 등).

## 사용법

**권장: 플러그인의 `/adopt`** — 폴더 상태에 따라 자동으로 경로를 고른다.

| 폴더 상태 | 동작 |
|---|---|
| 빈 폴더 | 템플릿 복사 → `/kickoff`로 아이디어 인터뷰 |
| 기존 코드 | 기존 파일을 덮어쓰지 않고 문서·진행 체계만 추가, 코드에서 역방향 문서화 |
| 이미 적용됨 | `.template-version` 이후 바뀐 부분만 반영 (3-way 병합) |

플러그인 설치 (컴퓨터마다 한 번, `gh auth login` 필요):

```bash
claude plugin marketplace add huny4daniel/huny4daniels-claude-plugin
claude plugin install project-process@huny4daniels
```

플러그인 없이:

```bash
gh repo create <이름> --private --template huny4daniel/huny4daniels-TEMPLATE --clone
# 또는 로컬 복사: powershell -File tools/scripts/new-project.ps1 -Name <이름> -Path <위치>
```

이후 프로젝트 폴더에서 `/kickoff`, 이어서 할 때는 `/next`.

**Windows**: 훅은 Git Bash로 실행된다. 찾지 못하면 셸 명령이 모두 막히므로 [guardrails.md](../docs/process/guardrails.md)의 `CLAUDE_CODE_GIT_BASH_PATH` 설정을 먼저 확인한다.

## 템플릿 관리

- 파일 소유 구분(템플릿 소유 / 프로젝트 소유 / 템플릿 전용)과 업데이트 절차: [docs/process/template-update.md](../docs/process/template-update.md)
- 템플릿 전용 파일(새 프로젝트로 복사하지 않음): `.github/README.md`, `.github/ROADMAP.md`, `tools/scripts/new-project.ps1`
- 도입 명령은 별도 저장소 [huny4daniels-claude-plugin](https://github.com/huny4daniel/huny4daniels-claude-plugin)에 있다. 템플릿 전용 파일 목록을 바꾸면 플러그인의 `adopt.md`와 `new-project.ps1`도 함께 고친다.
- 개선 계획: [ROADMAP.md](ROADMAP.md)
