# huny4daniels-TEMPLATE

**spec에서 구현까지**를 사람과 코딩 에이전트(Claude Code)가 함께 가는 프로젝트 템플릿.
사람은 무엇을 만들지 spec으로 정하고 승인하며, 에이전트는 그 spec을 따라 계획·구현·검증한다. 진행 절차, 세션 간 기억, 그리고 에이전트가 잊어도 항상 동작하는 **결정론적 장치(훅)**는 모두 이 spec을 지키기 위한 도구다.

> 이 파일은 템플릿 저장소 소개용이다(템플릿 전용, 새 프로젝트로 복사되지 않음).
> 루트의 [README.md](../README.md)는 새 프로젝트가 채워 쓸 README 뼈대다.

---

## 왜 만들었나

코딩 에이전트에게 일을 맡기면 네 가지 문제가 반복된다. 첫 번째가 이 템플릿의 중심이고, 나머지는 그것을 받치는 운영 문제다.

| 문제 | 증상 | 이 템플릿의 대응 |
|---|---|---|
| **만든 것이 의도와 다르다** | 그럴듯하게 동작하고 테스트도 통과하는데, 원래 정한 동작·예외 처리가 빠져 있다. 정한 내용은 대화나 일회용 계획 문서에 흩어진다 | 동작을 spec 한 곳에 ID가 붙은 시나리오로 적고, 계획·테스트·PR이 그 ID를 잇는다. 범위가 바뀌면 spec부터 고친다. 시나리오마다 테스트가 있는지는 기계가 검사한다(로드맵 G5) |
| **기억이 끊긴다** | 세션이 바뀌면 지난 결정·진행 상황을 다시 설명해야 한다 | `docs/STATUS.md`·계획 문서를 세션 간 기억으로 쓰고, 세션 시작 시 자동 로드 |
| **지시를 잊는다** | "테스트 돌려라", "main에 바로 push 하지 마라"를 가끔 어긴다 | 지켜야 하는 것은 문서가 아니라 **훅**으로 강제 |
| **어디까지 맡길지 모호하다** | 사소한 것까지 묻거나, 반대로 되돌리기 어려운 일을 혼자 한다 | 사람 승인이 필요한 **게이트**와 자율 영역을 표로 고정 |

## 설계 원칙

0. **spec이 중심이고 유일한 원본이다.** 범위와 동작은 spec에만 쓰고, 계획·이슈·STATUS·PR은 ID로 가리킨다. 운영 체계의 장치는 각각 spec과 이어지는 고리를 갖는다 — spec 승인 게이트, ID 사슬, spec 갱신 점검, 커버리지 검사. spec과 무관한 장치는 위험 명령 확인과 git 흐름 같은 기반 안전장치뿐이다. 강제는 기계가(테스트 존재·통과), 판단은 사람이(spec 승인, 미정 해소) 한다.
1. **확률적 지시와 결정론적 장치를 나눈다.** `AGENTS.md`·`PROCESS.md`는 에이전트가 지키려고 노력하는 규칙이고, `.claude/hooks/`는 에이전트가 잊어도 항상 실행되는 장치다. 장치로 강제할 수 있는 것은 지시문에 반복하지 않는다.
2. **사람이 보는 것과 에이전트 장치를 나눈다.** 저장소에서 사람에게 보이는 것은 코드, README, `docs/`(SPEC·STATUS·ADR·계획)뿐이고, 절차 문서·템플릿·명령·훅은 `.claude/`에 모은다. 작은 도구 저장소에서도 코드보다 절차가 먼저 보이지 않는다.
3. **컨텍스트는 필요한 만큼만.** 세션마다 자동 로드되는 것은 핵심 규칙·목차·현재 상태뿐이고(합계 상한을 템플릿 CI가 검사), 단계별 상세 절차(`.claude/process/`)와 spec의 기능 소절은 필요할 때만 읽는다.
4. **사람은 판단, 에이전트는 진행.** 사람은 아이디어·생각·판단과 사람만 할 수 있는 일을 맡고, 에이전트는 필요한 때에 묻고 그 답을 바탕으로 진행하며 다음 행동을 먼저 제안한다. 진행 중인 응답은 [질문] / [제안] / [승인 요청] / [요청] 중 하나로 끝난다(단순 질의응답에는 붙이지 않음).
5. **막기보다 확인.** 위험 명령은 차단하지 않고 확인 창을 띄운다(ask). 기계적으로 판단 가능한 위반(CI 실패 상태의 PR 병합)만 거부한다(deny).
6. **검증 루프는 끝나야 한다.** 자동 검사 실패로 응답 종료를 막되, 같은 실패는 한 번만 막고 훅으로 이어진 응답에서는 경고만 띄워 무한 반복을 막는다.
7. **업계 관행을 엮는다, 새로 발명하지 않는다.** Lean Canvas, 사용자 스토리·Given-When-Then, ADR(Nygard), C4, Walking Skeleton, GitHub Flow, SemVer, Keep a Changelog, Explore→Plan→Code→Commit.

## 구성

```
.
├── AGENTS.md              에이전트 공용 지침 (Claude Code·Codex·Copilot)
├── CLAUDE.md              Claude 전용 — AGENTS.md·.claude/process/PROCESS.md·docs/STATUS.md를 import
├── apps/ packages/ tools/ 모노레포 구조 (full만, apps → packages 단방향 의존)
├── docs/                  ← 사람이 보는 프로젝트 문서
│   ├── SPEC.md            spec — 무엇을 만드는가의 유일한 기준, 사람의 판단 기록
│   ├── STATUS.md          현재 단계·다음 할 일·결정·가정 (자동 로드, 세션 간 기억)
│   └── adr/ plans/ (full: architecture/ runbooks/ postmortems/ retros/)
├── .claude/               ← 에이전트가 쓰는 템플릿 장치 (사람이 읽을 필요 없음)
│   ├── process/           PROCESS.md(핵심 규칙·목차, 자동 로드)와 단계별 상세 절차
│   ├── templates/         ADR·계획·브리프·회고 등 문서 템플릿
│   ├── commands/          /kickoff /next /plan /adr /review /fix /wrap
│   ├── hooks/             guard.sh · check-file.sh · check-turn.sh · spec-coverage.sh · metrics.sh · lib.sh · checks.env
│   └── settings.json      훅 등록, 파일 도구의 비밀 파일 읽기 금지
└── .github/               CI 뼈대, 이슈·PR 템플릿
    ├── hook-tests/        훅 회귀 테스트 (템플릿 전용)
    └── workflows/template-ci.yml  템플릿 CI (템플릿 전용)
```

## 진행 흐름

```
0 초기화 → 1 아이디어·spec → 2 설계 → 3 계획 → [4 구현 ⇄ 5 검증] → 6 릴리즈 → 7 회고
             ↑ 큰 새 기능                 ↑________ 다음 마일스톤 ____________|
             |____________ 유지보수 모드 (버그 분류 → 수정 → PATCH) ←_______|
```

| 단계 | 사람이 하는 일 | 게이트 |
|---|---|---|
| 1 아이디어·spec | 인터뷰에 답하고, Claude가 쓴 spec 초안의 `[제안]`·`[미정]`을 판단 | Must 시나리오, `[제안]` 모두 확인, spec 승인 |
| 2 설계 | 스택·개발 환경·릴리즈 방식 선택 | 기술 선택 ADR 승인 |
| 3 계획 | 마일스톤·이슈 확인 | 이슈 분해 승인 |
| 4~5 구현·검증 | 이슈별 계획 승인, 실기기·체감 확인 | DoD, 사람 확인 |
| 6 릴리즈 | 버전·배포 승인 | 태그·릴리즈 |

상세: [.claude/process/PROCESS.md](../.claude/process/PROCESS.md)

### spec 규칙

에이전트는 계획을 세울 때 spec을 그대로 믿고 읽는다. 그래서 spec이 낡지 않게, 그리고 코드까지 추적되게 한다.

| 규칙 | 내용 |
|---|---|
| spec = `docs/SPEC.md` | 무엇을 만드는가의 유일한 기준. 기능마다 소절(`### F-03 이름 — Must · Done`), 사용자 스토리, Given-When-Then 시나리오(`F-03.1`). 계획·이슈·PR·STATUS는 ID로 가리키기만 한다. 자동 로드하지 않고 필요한 부분만 읽는다 |
| 판단의 기록 | `[확정]` 사람이 정함 / `[제안]` Claude 추천, 확인 전 / `[미정]` 결정 필요 — `[미정]`이 남은 기능은 착수하지 않고, 착수하려는 때에 묻는다. `(수동)` 자동화 불가, `[탐색]` 써 봐야 아는 기능 |
| 판단의 경계 | 보이는 동작·범위·트레이드오프는 사람, 표준이 분명한 것과 내부 구현은 Claude ([PROCESS.md](../.claude/process/PROCESS.md) 협업 규칙 2) |
| spec은 계속 갱신 | 범위·동작이 바뀌면 **같은 커밋/PR에서 SPEC.md를 먼저** 고치고 변경 이력에 남긴다. 기능은 지우지 않고 상태(`Planned`→`Done`/`Dropped`)로, 범위 밖 요청은 백로그 절에. `/review`·`/wrap`·PR 체크리스트가 누락을 점검 |
| ID 사슬 | `F-ID → 이슈 [F-01] → 계획 "구현할 시나리오" → 테스트 이름·주석(F-01.1) → PR`. 시나리오마다 실패하는 테스트부터(TDD). 버그는 spec 위반(회귀 테스트) / spec 공백(시나리오 먼저 추가)으로 나눈다 |
| lite일 때 | 같은 SPEC.md를 짧게. 시나리오는 테스트를 쓸 기능에만, 계획은 `docs/plans/mvp.md` 체크리스트(기능 ID만). 커버리지 검사는 그대로 |
| 기계적 강제 | `Done`이라고 적으려면 자동 시나리오마다 ID가 달린 테스트가 있어야 하고, `[제안]`·`[미정]`이 없어야 한다. Stop 훅·CI가 검사한다(`spec-coverage.sh`, 아래 안전장치 표) |
| spec 대조 | 마일스톤 끝에 존재는 기계(`spec-coverage.sh`)가, 의미는 Claude가 본다 — 테스트가 시나리오를 실제로 검증하는지, 코드에만 있는 동작은 없는지. 결과는 분류 표로, 할 일이 0이 될 때까지 4 ⇄ 5단계 반복 ([05-verify.md](../.claude/process/05-verify.md)) |
| 탐색 경로 | 써 봐야 아는 기능은 `[탐색]`으로 표시하고 `spike/` 브랜치에서 만들어 본 뒤, 알아낸 것을 보여주고 spec으로 / 버리기 / 계속을 사람이 고른다. 프로토타입은 병합하지 않는다 ([04-build.md](../.claude/process/04-build.md)) |

## 안전장치

| 시점 | 장치 | 동작 |
|---|---|---|
| 셸 명령 직전 | `guard.sh` (PreToolUse) | main/태그/force push, PR 병합, 릴리즈, 재귀 삭제, 배포, 외부 API 쓰기, **셸로 비밀 파일 다루기** → 확인 창. PR 병합은 `gh pr checks`로 CI를 조회해 실패·진행 중이면 거부. 판정 대상은 명령 문자열뿐이고(description·cwd 무시), main push는 `git push`의 대상·현재 브랜치·upstream으로 판정 |
| 파일 수정 직후 | `check-file.sh` (PostToolUse) | 포매터·린터 실행, 오류면 에이전트에게 되돌림 |
| 응답 종료 시 | `check-turn.sh` (Stop) | 코드가 바뀌었으면 린트·타입 체크·테스트, 실패면 종료를 막고 고치게 함 (같은 상태 재검사 생략, 반복 방지) |
| 응답 종료 시·CI | `spec-coverage.sh` | **spec대로 만들었는가**: `Done` 기능의 시나리오마다 테스트에 ID가 있는지, `Done` 기능에 사람 확인 전 판단(`[제안]`·`[미정]`)이 남지 않았는지 검사해 실패면 막는다. `--summary`는 `/next`가 쓰는 spec 상태 요약 |
| 파일 도구 사용 시 | `settings.json` deny | `.env`·키스토어·인증서·SSH 키를 Read 등 파일 도구로 읽지 못하게 함 (셸 경유는 위 `guard.sh` 확인 창) |
| 커밋·push (Claude 밖) | `.githooks/` | 사람이나 다른 에이전트의 커밋에도 같은 린트, push에 테스트·spec 커버리지. `checks.env`를 그대로 읽는다(0단계에서 `core.hooksPath`) |
| PR | CI | 설치·린트·타입 체크·테스트·빌드, spec 커버리지 |

검사 명령은 `.claude/hooks/checks.env` 한 곳에서 정하고, `AGENTS.md` 명령 표·CI와 같게 유지한다. 템플릿 상태에서는 비어 있어 꺼져 있다. 훅 공용 함수(JSON 필드 추출, 경로 변환)는 `.claude/hooks/lib.sh`에 있다.

**효과도 기록한다**: 훅이 판정할 때마다 분류와 시간만 `.claude/metrics/events.jsonl`(로컬)에 남기고, `metrics.sh`가 확인 창 횟수, 차단 뒤 스스로 고친 비율, spec 커버리지 차단 횟수, 검사 시간을 요약한다. `/wrap`이 세션 로그에 한 줄로 옮긴다.

**안전장치 자체도 검증한다**: `.github/hook-tests/`(bats)에 판정 픽스처 표와 훅별 회귀 테스트가 있고, 템플릿 CI(`template-ci.yml`)가 ubuntu·Windows에서 shellcheck·줄바꿈 검사와 함께 매 push마다 돌린다. 모든 셸 명령마다 실행되는 `guard.sh`는 성능 기준(케이스당 평균 시간)도 테스트한다.

**알려진 한계**: 명령 문자열 패턴으로 판정하므로 스크립트 파일 안의 명령, 변수로 조립한 명령·경로, MCP 도구 호출은 잡지 못한다(이런 작업은 절차의 사람 승인 게이트로 다룸). 비밀 파일 이름을 언급만 하는 명령에도 확인 창이 뜨는 오탐이 있다. Claude Code를 거치지 않은 push·병합(터미널·IDE 직접 조작)은 git 훅이 테스트·spec 커버리지를 검사하지만, main 직접 push 자체를 막지는 못한다(비공개 저장소 보호 규칙은 유료 플랜). OS 수준으로 막으려면 샌드박스를 켤 수 있다 — 자세한 내용은 [guardrails.md](../.claude/process/guardrails.md), 남은 개선은 [로드맵](ROADMAP.md).

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

**규모**: 1단계 인터뷰 끝에 lite / full을 정한다. lite(앱 하나, 사용자 본인·소수, 결제·개인정보 없음, MVP 한두 주)는 SPEC.md를 짧게 쓰고, 1·2단계 승인을 한 번에 받고, 이슈 대신 체크리스트로 진행하며, 쓰지 않는 문서·폴더(설계 문서, runbook, 모노레포 구조 등)를 두지 않는다. 규칙(spec이 기준, 판단은 사람, 훅·커버리지 검사)은 같다. 한 번 쓰고 버릴 스크립트나 하루짜리 실험에는 템플릿을 쓰지 않는다 — `/kickoff`가 그렇게 보이면 먼저 묻는다. 자세한 기준: [01-idea-spec.md](../.claude/process/01-idea-spec.md) "규모".

**Windows**: 훅은 Git Bash로 실행된다. 찾지 못하면 셸 명령이 모두 막히므로 [guardrails.md](../.claude/process/guardrails.md)의 `CLAUDE_CODE_GIT_BASH_PATH` 설정을 먼저 확인한다.

## 템플릿 관리

- 파일 소유 구분(템플릿 소유 / 프로젝트 소유 / 템플릿 전용)과 업데이트 절차: [.claude/process/template-update.md](../.claude/process/template-update.md)
- 템플릿 전용 파일(새 프로젝트로 복사하지 않음)의 목록은 루트의 [`.template-only`](../.template-only) 하나에만 있다. 생성 스크립트·플러그인 `/adopt`·초기화·업데이트 절차가 모두 이 파일을 읽고, 템플릿 CI가 목록의 경로가 실제로 있는지와 다른 곳에 목록이 따로 적혀 있지 않은지 검사한다.
- 도입 명령은 별도 저장소 [huny4daniels-claude-plugin](https://github.com/huny4daniel/huny4daniels-claude-plugin)에 있다. 템플릿과 플러그인을 함께 바꿀 때는 **템플릿을 먼저 병합하고 플러그인을 나중에** 병합한다(플러그인이 아직 없는 템플릿 파일을 가리키는 순간이 생기지 않게).
- 훅을 고치는 커밋에는 `.github/hook-tests/`의 케이스 추가를 함께 넣는다. 로컬 실행: `bats .github/hook-tests` ([bats-core](https://github.com/bats-core/bats-core) 1.11).
- 개선 계획: [ROADMAP.md](ROADMAP.md)
