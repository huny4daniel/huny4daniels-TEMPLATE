# 안전장치와 자동 검증

AI의 판단에 맡기지 않고 **기계적으로** 동작하는 장치들. 지시문(AGENTS.md, PROCESS.md)은 Claude가 지키려고 노력하는 규칙이고, 아래는 Claude가 잊어도 항상 실행되는 장치다.

| 계층 | 장치 | 위치 | 동작 |
|---|---|---|---|
| 규칙 문서 | 코딩 컨벤션·아키텍처 제약·자주 하는 실수 | `AGENTS.md` | 세션마다 자동 로드 |
| 위험 작업 확인 | PreToolUse 훅 | `.claude/hooks/guard.sh` | 위험 명령 직전에 사람 확인 창 |
| 파일 수정 직후 검사 | PostToolUse 훅 | `.claude/hooks/check-file.sh` | 수정한 파일에 포매터·린터 실행, 오류면 Claude에게 되돌림 |
| 응답 종료 시 검사 | Stop 훅 | `.claude/hooks/check-turn.sh` | 코드가 바뀌었으면 타입 체크·단위 테스트, 실패면 응답 종료를 막고 고치게 함 |
| spec 커버리지 | Stop 훅·CI | `.claude/hooks/spec-coverage.sh` | `Done` 기능의 자동 시나리오마다 테스트에 ID가 있는지, `Done` 기능에 `[제안]`·`[미정]`·`[탐색]`이 남지 않았는지 검사. 실패면 응답 종료를 막는다 |
| 비밀 파일 — 파일 도구 | 권한 deny | `.claude/settings.json` | Read·Grep 등 **파일 도구**로 `.env`, 키스토어, 인증서, SSH 키 읽기 금지 (셸 명령에는 적용되지 않음) |
| 비밀 파일 — 셸 경유 | PreToolUse 훅 | `.claude/hooks/guard.sh` | 셸 명령에 비밀 파일 이름이 있으면 확인 창 (`cat .env`, `cp .env …`, `base64 *.jks` 등). 막지는 않음 |
| 병합 전 검사 | CI | `.github/workflows/ci.yml` | PR마다 설치·린트·타입 체크·테스트·빌드 |
| main 보호 | GitHub ruleset (선택) | 저장소 설정 | PR·CI 통과 없이 main 반영 금지 ([git-flow.md](git-flow.md)) |

훅은 bash로 실행된다. 조정·끄기는 `/hooks` 메뉴 또는 `.claude/settings.json`.

**Windows 주의**: Claude Code가 Git Bash(Git for Windows)를 찾아야 훅이 동작한다. 찾지 못하면 훅이 PowerShell로 실행되어 실패하고, 이때 모든 셸 명령이 막힌다 (오류 메시지에 "Git Bash wasn't found"). Git을 표준 위치가 아닌 곳에 설치했다면 사용자 설정(`~/.claude/settings.json`)에 경로를 지정한다:

```json
{ "env": { "CLAUDE_CODE_GIT_BASH_PATH": "C:\\설치경로\\Git\\bin\\bash.exe" } }
```

## 위험 작업 확인 (guard.sh)

막지 않고 확인 창을 띄운다. 사람이 확인하면 그대로 진행된다.

| 분류 | 대상 명령 |
|---|---|
| main 반영 | main/master push, main에 있는 상태의 push, force push |
| PR 병합 | `gh pr merge` 전에 `gh pr checks`로 CI 상태를 조회한다. **실패·진행 중이면 거부**(확인 창 없이 막음), 통과면 확인 창, CI 결과가 없거나 조회할 수 없으면 그 사실을 알리고 확인 창 |
| 릴리즈 | 버전 태그 push, `gh release create/delete/edit/upload` |
| 삭제·되돌리기 불가 | `rm -r`, `Remove-Item -Recurse`, `git reset --hard`, `git clean -f`, `git branch -D`, `git checkout/restore .`, `git stash drop/clear`, 원격 브랜치·태그 삭제, `gh repo/issue/secret delete`, 저장소 보관·공개 범위 변경 |
| 배포 | `npm/pnpm/uv/poetry/cargo publish`, `gradle publish`, `docker push`, `kubectl/helm/terraform` 적용, `firebase/vercel/netlify/fly` 배포 등 |
| 외부 API 쓰기 | `curl/wget/Invoke-*`의 POST·PUT·PATCH·DELETE·데이터 전송, `gh api` 쓰기 요청 |
| 비밀 파일 접근 | 명령에 `.env`(`.env.local` 등 포함), `*.jks`·`*.keystore`·`*.pem`·`*.p12`·`*.pfx`·`*.key`, `id_rsa`·`id_ed25519`가 있으면 읽기 명령이 아니어도 확인 (복사·인코딩·다른 언어로 열기 우회 포함). `.env.example`·`.env.sample` 같은 예시 파일은 제외 |

판정 대상은 **명령 문자열(`tool_input.command`) 하나뿐**이다. 설명(description)·작업 경로(cwd) 같은 다른 필드는 보지 않는다. main 직접 push는 명령을 `&&`·`;`·`|` 단위로 나눠 각 `git push`의 **대상**으로 판정한다: 대상이 main/master(`feature/x:main`, `HEAD:refs/heads/main` 포함)이거나, 대상 없이 push할 때 현재 브랜치 또는 upstream이 main/master이거나, `--all`·`--mirror`이면 확인한다.

통과하는 것: 조회(GET, `gh ... view/list`), 작업 브랜치 push, PR 생성, 이슈·라벨·마일스톤 생성, 일반 파일 삭제(`rm 파일`), 빌드·테스트 명령, 커밋 메시지·로그 조회에 main이 들어간 명령.

한계: 명령 문자열 패턴으로 판정하므로 다음은 잡지 못한다.
- 스크립트 파일 안에서 실행되는 위험 명령, MCP 도구 호출 → PROCESS.md 게이트 규칙(사람 승인)으로 다룬다.
- 변수로 조립한 경로·명령 (예: `f=.e; cat ${f}nv`).
- 오탐이 있다: 비밀 파일 이름을 언급만 하는 명령(예: `.gitignore`에 `.env`를 추가하는 `echo`)도 확인 창이 뜬다. 확인 창이라 감수한다.

**더 강하게 막으려면 (선택)**: Claude Code 샌드박스(`"sandbox": { "enabled": true }`)를 켜면 `Read(...)` deny 규칙이 Bash 명령에도 OS 수준으로 적용되어 패턴 우회가 불가능해진다. 다만 네트워크·쓰기 제한도 함께 걸려 gh·패키지 설치·빌드에 허용 설정이 필요하므로 템플릿 기본값으로는 켜지 않는다. 쓰는 Claude Code 버전의 문서에서 지원 범위를 확인하고 프로젝트별로 결정한다(결정하면 ADR).

## spec 커버리지 (spec-coverage.sh)

"spec대로 만들었는가"를 기계적으로 확인하는 장치다. 린트·테스트는 "코드가 깨지지 않았는가"만 본다.

| 검사 | 실패 조건 |
|---|---|
| 시나리오별 테스트 | SPEC.md에서 상태가 `Done`인 기능의 자동 시나리오(`(수동)` 제외) ID가 `SPEC_TEST_GLOB` 파일 어디에도 없다. ID 형식은 `F-03.1` 또는 `f03_1`·`F03_1` |
| 사람의 판단 | `Done` 기능에 `[제안]`·`[미정]` 시나리오가 남아 있다 — 사람이 확인하지 않은 판단은 완료가 될 수 없다 |
| 탐색 | `[탐색]` 기능이 `Done`이다 — 탐색을 끝내고 시나리오를 쓴 뒤 `[탐색]`을 뗀다 |

- `Planned`·`In Progress` 기능은 검사하지 않는다. 개발 중에 매번 막히지 않게 하고, 규칙을 **"Done이라고 적으려면 시나리오마다 테스트가 있어야 한다"**로 둔다.
- 테스트에만 있고 spec에 없는 ID는 참고로 알린다(실패 아님).
- 실행 시점: Stop 훅(SPEC.md나 코드가 바뀌었을 때 — spec만 바뀌면 타입 체크·테스트는 돌리지 않고 이 검사만), CI(`ci.yml`의 spec 커버리지 스텝), 릴리즈 전(06-release.md).
- 설정: `checks.env`의 `SPEC_FILE`, `SPEC_TEST_GLOB`. glob이 비어 있으면 검사하지 않는다. 3단계 Walking Skeleton에서 채운다.
- **요약**: `bash .claude/hooks/spec-coverage.sh --summary`는 기능별 우선순위·상태·`[미정]`·`[제안]` 수와 커버리지, 다음 후보를 한 화면으로 출력한다. `/next`와 세션 시작 브리핑이 SPEC.md 전체 대신 이것을 읽는다.
- **한계**: ID가 테스트 파일에 있는지만 본다. 그 테스트가 시나리오를 제대로 검증하는지는 `/review`와 5단계 spec 대조가 본다. 기계는 존재를, 리뷰는 의미를 본다.

## 자동 검증 (check-file.sh, check-turn.sh)

설정은 `.claude/hooks/checks.env` 한 곳에 둔다. 비어 있으면 아무것도 하지 않으므로 템플릿 상태에서는 꺼져 있고, **3단계 Walking Skeleton에서 AGENTS.md 명령과 같게 채운다.**

| 항목 | 실행 시점 | 실패 시 |
|---|---|---|
| `FORMAT_CMD` | 대상 파일(`FILE_PATTERN`)을 수정한 직후 | 무시 (포맷만 적용) |
| `LINT_CMD` | 〃 | 오류를 Claude에게 되돌려 바로 고치게 함 |
| `TYPECHECK_CMD`, `TEST_CMD` | Claude가 응답을 마치려 할 때, 코드 파일이 바뀌었을 때만 | 응답 종료를 막고 실패 내용으로 고치게 함 |

- 명령은 셸로 해석되므로 따옴표·`&&`를 쓸 수 있다. 예: `TEST_CMD='cd apps/android && ./gradlew test'`, `TEST_CMD='uv run pytest -q -m "not slow"'`
- 응답 종료 시 린트는 바뀐 코드 파일 전체에 다시 돌린다 (셸 명령으로 고친 파일도 잡기 위함).
- 같은 상태로 이미 통과했으면 다시 돌리지 않는다 (`.claude/hooks/.last-pass`, git 제외).
- 같은 실패는 한 번만 막는다 (`.claude/hooks/.last-fail`). 실패 중인 테스트를 두고 사람의 답을 기다릴 때(예: 버그 수정 중 계획 승인 요청)는 막힌 응답에서 이유를 설명하고 [질문]으로 끝내면 되고, 이후 같은 상태에서는 경고만 뜬다. 훅으로 이어진 응답에서 또 실패해도 경고만 띄운다 (무한 반복 방지). 어느 경우든 Claude는 실패를 숨기지 않고 보고한다.
- 단위 테스트가 길어지면(수십 초 이상) `TEST_CMD`를 빠른 테스트 묶음으로 좁히고, 전체 테스트는 CI에 맡긴다.

## git 훅 (.githooks/)

Claude Code 훅은 Claude를 거친 작업에만 걸린다. 사람이 터미널·IDE에서 직접 하거나 다른 에이전트(Codex 등)가 하는 커밋·push에도 같은 검사를 걸기 위해, 같은 `checks.env`를 읽는 git 훅을 둔다. 켜기: `git config core.hooksPath .githooks`(0단계, 컴퓨터마다 한 번).

| 훅 | 하는 일 | 실패 시 |
|---|---|---|
| `pre-commit` | 스테이징된 코드 파일(`FILE_PATTERN`)에 `LINT_CMD` | 커밋 중단 |
| `pre-push` | `TEST_CMD`, spec 커버리지(`SPEC_TEST_GLOB`가 있으면). main·태그 push는 알림만 | push 중단 |

- 명령이 비어 있으면 아무것도 하지 않는다.
- 사람은 `--no-verify`로 건너뛸 수 있다(실수 방지가 목적). 에이전트는 AGENTS.md 규칙 8에 따라 우회하지 않는다.
- main 직접 push를 **막지는** 않는다 — 비공개 저장소에서 막으려면 GitHub 보호 규칙(유료 플랜)이 필요하다([git-flow.md](git-flow.md) "main 보호").

## 훅 이벤트 로그

템플릿이 실제로 일하고 있는지 보여주는 근거다. 훅 세 개가 판정할 때마다 `.claude/metrics/events.jsonl`(git 제외, 로컬에만)에 한 줄씩 남긴다.

| 훅 | 남기는 것 |
|---|---|
| guard.sh | 확인 창(ask)·거부(deny)와 그 분류(`main 반영`, `비밀 값`, `CI 실패` 등). 통과한 명령은 남기지 않는다 |
| check-turn.sh | 통과·차단·경고, 차단한 검사 종류(`테스트`, `spec 커버리지` 등), 걸린 시간(ms) |
| check-file.sh | 파일 수정 직후 린트 실패 |

- 명령 원문·파일 내용은 남기지 않는다(비밀 값이 섞일 수 있음). 세션 ID와 분류만 남긴다.
- 기록에 실패해도 판정에는 영향이 없다. `HOOK_EVENT_LOG=0`이면 끈다.
- 요약: `bash .claude/hooks/metrics.sh`(오늘), `metrics.sh 2026-11`(그 달), `metrics.sh all`. 확인 창·거부 분류별 횟수, 응답 종료 검사의 통과·차단·경고, **차단 뒤 같은 세션에서 통과한 비율(스스로 고친 비율)**, 검사 시간 중앙값·최대를 보여준다. `/wrap`이 세션 로그에 한 줄로 옮긴다.

## 컨텍스트 예산

세션마다 자동 로드되는 문서(CLAUDE.md가 import하는 `AGENTS.md`, `docs/PROCESS.md`, `docs/STATUS.md`)는 매 세션의 컨텍스트를 차지한다. 커질수록 규칙이 묻히고 비용이 는다.

- **spec(`docs/SPEC.md`)은 자동 로드하지 않는다.** 프로젝트마다 크기가 크게 다르다. `/next`·세션 브리핑은 기능 제목 줄과 `[미정]`·`[제안]` 표시만 읽고, `/plan`·`/review`는 해당 기능 소절만 읽는다.
- **상한**: 템플릿 상태 기준 합계 16KB(CLAUDE.md 1KB, AGENTS.md 5KB, PROCESS.md 10KB, STATUS.md 2.5KB). 템플릿 CI가 검사한다. 규칙을 추가할 때 상한을 넘으면 상세는 단계 문서로 옮기고 PROCESS.md에는 한 줄과 링크만 둔다.
- **프로젝트에서 자라는 부분의 배출구** (`/wrap`이 넘으면 정리를 제안):
  - STATUS.md 결정 기록이 15줄을 넘으면 오래된 것을 `docs/decisions-log.md`(자동 로드 안 함)로 옮긴다. 세션 로그는 10개 유지(기존 규칙).
  - AGENTS.md Gotchas가 한 영역에 몰리면 그 폴더의 하위 `AGENTS.md`로 옮긴다(그 폴더를 작업할 때만 읽힌다).
- 실제 사용량은 Claude Code의 `/context`로 확인할 수 있다.
