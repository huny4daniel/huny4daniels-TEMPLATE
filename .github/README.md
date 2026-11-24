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
│   ├── hooks/             guard.sh · check-file.sh · check-turn.sh · lib.sh · checks.env
│   └── settings.json      훅 등록, 파일 도구의 비밀 파일 읽기 금지
└── .github/               CI 뼈대, 이슈·PR 템플릿
    ├── hook-tests/        훅 회귀 테스트 (템플릿 전용)
    └── workflows/template-ci.yml  템플릿 CI (템플릿 전용)
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

### spec 규칙

에이전트는 계획을 세울 때 spec을 그대로 믿고 읽는다. 그래서 spec이 낡지 않게, 그리고 코드까지 추적되게 한다.

| 규칙 | 내용 |
|---|---|
| spec은 계속 갱신 | spec = `docs/product/PRD.md`. 범위·동작이 바뀌면 **같은 커밋/PR에서 spec을 먼저** 고치고 변경 이력에 남긴다. STATUS.md 결정 기록엔 한 줄과 링크만. 요구사항은 지우지 않고 상태(`Planned`→`Done`/`Dropped`)로 관리, 범위 밖 요청은 백로그 절에. `/review`·`/wrap`·PR 체크리스트가 누락을 점검 |
| 요구사항 ID | 기능 `F-01`, 비기능 `NF-01`, 시나리오 `F-01.1`. 재사용 금지. `F-ID → 이슈 [F-01] → 계획 → 테스트 이름·주석 → PR`로 잇고, 마일스톤 끝에 Must마다 Done·이슈·테스트를 확인 |
| 수용 기준 | 계획·이슈는 spec에 정의된 시나리오 ID를 참조한다. 시나리오 형식(Given-When-Then)과 위치는 설계 변경 중 ([ROADMAP](ROADMAP.md) G2) |
| lite일 때 | 브리프(`idea-brief.md`)가 spec. MVP 기능 목록에 F-ID, "변경 이력"·"나중에"(백로그) 절로 같은 갱신 규칙. 추적 사슬은 `F-ID → mvp.md 체크리스트 항목 → 테스트`로 줄인다 (lite 모드 자체는 ROADMAP D1에서 도입 예정) |

## 안전장치

| 시점 | 장치 | 동작 |
|---|---|---|
| 셸 명령 직전 | `guard.sh` (PreToolUse) | main/태그/force push, PR 병합, 릴리즈, 재귀 삭제, 배포, 외부 API 쓰기, **셸로 비밀 파일 다루기** → 확인 창. PR 병합은 `gh pr checks`로 CI를 조회해 실패·진행 중이면 거부. 판정 대상은 명령 문자열뿐이고(description·cwd 무시), main push는 `git push`의 대상·현재 브랜치·upstream으로 판정 |
| 파일 수정 직후 | `check-file.sh` (PostToolUse) | 포매터·린터 실행, 오류면 에이전트에게 되돌림 |
| 응답 종료 시 | `check-turn.sh` (Stop) | 코드가 바뀌었으면 린트·타입 체크·테스트, 실패면 종료를 막고 고치게 함 (같은 상태 재검사 생략, 반복 방지) |
| 파일 도구 사용 시 | `settings.json` deny | `.env`·키스토어·인증서·SSH 키를 Read 등 파일 도구로 읽지 못하게 함 (셸 경유는 위 `guard.sh` 확인 창) |
| PR | CI | 설치·린트·타입 체크·테스트·빌드 |

검사 명령은 `.claude/hooks/checks.env` 한 곳에서 정하고, `AGENTS.md` 명령 표·CI와 같게 유지한다. 템플릿 상태에서는 비어 있어 꺼져 있다. 훅 공용 함수(JSON 필드 추출, 경로 변환)는 `.claude/hooks/lib.sh`에 있다.

**안전장치 자체도 검증한다**: `.github/hook-tests/`(bats)에 판정 픽스처 표와 훅별 회귀 테스트가 있고, 템플릿 CI(`template-ci.yml`)가 ubuntu·Windows에서 shellcheck·줄바꿈 검사와 함께 매 push마다 돌린다. 모든 셸 명령마다 실행되는 `guard.sh`는 성능 기준(케이스당 평균 시간)도 테스트한다.

**알려진 한계**: 명령 문자열 패턴으로 판정하므로 스크립트 파일 안의 명령, 변수로 조립한 명령·경로, MCP 도구 호출은 잡지 못한다(이런 작업은 절차의 사람 승인 게이트로 다룸). 비밀 파일 이름을 언급만 하는 명령에도 확인 창이 뜨는 오탐이 있다. Claude Code를 거치지 않은 push·병합(터미널·IDE 직접 조작)도 막지 못한다. OS 수준으로 막으려면 샌드박스를 켤 수 있다 — 자세한 내용은 [guardrails.md](../docs/process/guardrails.md), 남은 개선은 [로드맵](ROADMAP.md).

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
- 템플릿 전용 파일(새 프로젝트로 복사하지 않음): `.github/README.md`, `.github/ROADMAP.md`, `.github/hook-tests/`, `.github/workflows/template-ci.yml`, `tools/scripts/new-project.ps1`
- 도입 명령은 별도 저장소 [huny4daniels-claude-plugin](https://github.com/huny4daniel/huny4daniels-claude-plugin)에 있다. 템플릿 전용 파일 목록을 바꾸면 플러그인의 `adopt.md`와 `new-project.ps1`도 함께 고친다 (전체 목록: [ROADMAP.md](ROADMAP.md) "변경 시 함께 고칠 곳").
- 훅을 고치는 커밋에는 `.github/hook-tests/`의 케이스 추가를 함께 넣는다. 로컬 실행: `bats .github/hook-tests` ([bats-core](https://github.com/bats-core/bats-core) 1.11).
- 개선 계획: [ROADMAP.md](ROADMAP.md)
