# 템플릿 개선 로드맵

템플릿 전용 문서(새 프로젝트로 복사되지 않음). 2026-11-24 기준 점검 결과와 개선 방법을 정리한다.
항목마다 **문제 → 근거 → 방법 → 완료 기준** 순서로 적는다. 끝낸 항목은 체크하고 커밋 SHA를 단다.

## 우선순위 요약

| 순서 | 묶음 | 항목 | 왜 지금 |
|---|---|---|---|
| 1 | 안전·정확성 | [A1](#a1-셸을-거친-비밀-파일-읽기) [A2](#a2-guardsh가-명령-외의-필드까지-검사함) [A3](#a3-check-filesh의-json-파싱) | 실제로 뚫리거나 오판하는 구멍 |
| 2 | 검증 | [B1](#b1-훅-회귀-테스트와-템플릿-ci) | A 묶음을 고칠 때 다른 판정이 깨지지 않게 |
| 3 | 측정 | [C1](#c1-훅-이벤트-로그) [C2](#c2-프로젝트-단위-지표-리포트) | 데이터는 나중에 만들 수 없다 — 지금부터 쌓여야 함 |
| 4 | 사용성 | [D1](#d1-lite-모드) [D2](#d2-응답-꼬리표-규칙-완화) [D3](#d3-컨텍스트-예산) | 작은 프로젝트에서 체감 비용을 줄임 |
| 5 | 확장 | [E1](#e1-git-훅으로-같은-검사-공유) [E2](#e2-템플릿-설계-결정-기록) | 다른 에이전트·사람 경로까지 덮음, 나중의 "왜"를 남김 |
| 6 | 공개 전환 시 | [F1](#f1-공개-전환-체크리스트) | 공개할 때 |

---

## A. 안전·정확성

### A1. 셸을 거친 비밀 파일 읽기

- [ ] 완료

**문제**: `settings.json`의 `Read(./.env)` 등 deny 규칙은 Claude Code의 파일 도구(Read·Grep·Glob 등)에만 적용된다. Bash/PowerShell에서 `cat .env`, `Get-Content .env`, `type .env`는 그대로 실행되고, `guard.sh`도 이를 판정하지 않는다. `guardrails.md`는 "비밀 값 차단"이라고 적고 있어 실제보다 강하게 보인다.

**방법**:
1. `guard.sh`에 5번째 분류 "비밀 파일 접근"을 추가한다. 빠른 통과 정규식에도 해당 파일명을 넣는다.
   ```bash
   # 5) 비밀 파일 접근: 셸에서 .env·키스토어·인증서를 읽거나 복사·전송
   secret='(\.env([^.a-z]|\.[a-z]+|$)|\.(jks|keystore|pem|p12|pfx|key)([^A-Za-z0-9]|$)|id_(rsa|ed25519))'
   if has "$secret" && ! has '\.env\.example'; then
     ask "[비밀 값] 비밀 파일을 셸로 읽거나 다루는 명령입니다. 값을 출력·전송하지 않는지 확인하세요."
   fi
   ```
   - 읽기 명령(`cat`·`type`·`Get-Content`·`less`·`head`·`grep`)으로 좁히지 않고 **파일명 기준**으로 판정한다. `cp .env /tmp/x`, `python -c "open('.env')"`, `base64 release.jks` 같은 우회까지 잡기 위함이다. 오탐(예: `.gitignore`에 `.env` 추가하는 echo)은 확인 창이라 감수한다.
   - CI 릴리즈 워크플로를 만들 때 키스토어를 다루는 명령도 확인 창이 뜨는데, 이는 의도된 동작이다.
2. 가능하면 Claude Code 샌드박스의 파일시스템 읽기 제한을 함께 쓴다. OS 수준에서 막으므로 패턴 우회가 불가능하다. 지원 범위(특히 Windows)는 쓰는 버전의 문서를 확인하고, 지원되면 `settings.json`에 추가한다.
3. `guardrails.md` 표의 "비밀 값 차단" 행을 둘로 나눈다: "Read 도구 읽기 금지(deny)" / "셸 경유 접근 확인(guard.sh)". 한계 문단에 "변수로 조립한 경로는 잡지 못함"을 추가한다.

**완료 기준**: B1 테스트에 `cat .env` → ask, `cat .env.example` → 통과, `Get-Content apps/android/keystore/release.jks` → ask 케이스가 있고 통과한다.

### A2. guard.sh가 명령 외의 필드까지 검사함

- [ ] 완료

**문제**: `guard.sh`는 훅 입력 JSON 전체(`$input`)에 정규식을 건다. 이 JSON에는 `tool_input.command` 외에 `description`, `cwd`, `transcript_path`, `session_id`가 들어 있다. 그 결과 두 방향으로 틀린다.
- **놓침(위험)**: main 직접 push 판정은 `feature/|fix/|docs/|HEAD:`가 입력 어디에든 있으면 건너뛴다. 현재 브랜치가 main인데 `git push`의 description이 "docs/STATUS.md 갱신 후 푸시"면 확인 창 없이 main에 push된다.
- **오탐**: 작업 폴더 경로에 `main`이라는 폴더가 있거나 description에 "main"이 들어가면, 작업 브랜치 push에도 확인 창이 뜬다.

재현 확인(2026-11-24): main 브랜치 저장소에서 `git push` + description "docs/STATUS.md 갱신 후 푸시" → 확인 창 없음. `git push origin feature/x` + cwd `C:\work\main\app` → "main 브랜치 push" 확인 창. A1의 `cat .env`도 확인 창 없이 통과.

**방법**:
1. 공용 함수 파일 `.claude/hooks/lib.sh`를 만들고, jq 없이 `tool_input.command`(PostToolUse는 `tool_input.file_path`)만 꺼내는 함수를 둔다. JSON 문자열의 이스케이프(`\"`, `\\`, `\n`)까지 처리한다.
   ```bash
   # json_field <키>: 첫 번째 "<키>": "<문자열>" 값을 디코딩해 출력 (jq 없이, 이스케이프 처리)
   json_field() {
     local re="\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\""
     [[ $input =~ $re ]] || return 1
     local v="${BASH_REMATCH[1]}"
     v="${v//\\\\/$'\x01'}"; v="${v//\\\"/\"}"; v="${v//\\n/$'\n'}"; v="${v//\\t/$'\t'}"
     v="${v//\\\//\/}"; v="${v//$'\x01'/\\}"
     printf '%s' "$v"
   }
   ```
   (`\uXXXX` 한글 이스케이프는 Claude Code가 보통 UTF-8 그대로 보내므로 처리하지 않는다. 테스트로 확인한다.)
2. `guard.sh` 맨 앞에서 `cmd="$(json_field command)" || exit 0`으로 바꾸고, `has`/`hasc`가 `$input` 대신 `$cmd`를 보게 한다.
3. main 직접 push 예외 판정을 "입력에 `feature/`가 있다"에서 **"push 대상 refspec이 main/master가 아니다"**로 바꾼다. `git push origin feature/x` → 통과. 인자 없는 `git push`·`git push origin HEAD` → 현재 브랜치와 upstream을 확인한다(`git rev-parse --abbrev-ref @{u}`).
4. `&&`·`;`로 이어진 복합 명령은 지금처럼 전체 명령 문자열에 판정을 건다(부분 명령으로 나누지 않음). 하나라도 걸리면 확인한다.

**완료 기준**: B1에 description·cwd 기반 오탐/놓침 케이스가 들어가 있고, 수정 전 코드에서는 실패, 수정 후 통과한다.

### A3. check-file.sh의 JSON 파싱

- [ ] 완료

**문제**: `"file_path":"..."`를 `[^"]*`로 잘라내므로 경로에 따옴표가 있으면 깨진다. 백슬래시는 `\\` → `/`로만 바꿔 다른 이스케이프는 처리하지 않는다.

**방법**: A2의 `json_field file_path`를 그대로 쓴다. Windows 경로는 `\` → `/`로 바꾼 뒤 `cygpath -u`가 있으면 거친다(Git Bash). `check-turn.sh`의 `stop_hook_active` 판정도 같은 파일의 함수(`json_bool`)로 통일한다.

**완료 기준**: B1에 공백·한글·따옴표가 들어간 Windows 경로 케이스가 있다.

---

## B. 검증

### B1. 훅 회귀 테스트와 템플릿 CI

- [ ] 완료

**문제**: `guard.sh`는 정규식 수십 개로 판정하는데 테스트가 없다. 템플릿 자체에 CI도 없다(`ci.yml`은 프로젝트용 자리표시자). 에이전트에게는 "테스트 없이 넘어가지 마라"고 요구하면서 안전장치 코드는 검증하지 않는 셈이다. 실제로 A2의 놓침도 테스트가 있었다면 드러났을 종류다.

**방법**:
1. **위치**(템플릿 전용, 프로젝트로 복사 안 함): `.github/hook-tests/`, `.github/workflows/template-ci.yml`
   - `ci.yml`은 프로젝트 소유 자리표시자이므로 건드리지 않는다.
   - 템플릿 전용 목록(`template-update.md`, `new-project.ps1`, 플러그인 `adopt.md`)에 추가한다.
2. **도구**: bats-core. 외부 의존 없이 bash로 돈다. 판정 결과는 표(픽스처)로 관리해, 케이스 추가를 한 줄로 끝낸다.
   ```
   # .github/hook-tests/guard-cases.tsv
   # 기대값   명령                                        메모
   pass      git status
   pass      git push origin feature/12-login
   ask       git push origin main
   ask       git push --force origin feature/x
   ask       git push origin v1.2.0
   ask       rm -rf build
   pass      rm build.log
   ask       Remove-Item -Recurse -Force dist
   ask       cat .env                                    A1
   pass      cat .env.example                            A1
   ask       curl -X POST https://example.com/api
   pass      curl https://example.com
   ask       gh api repos/o/r/rulesets -X POST
   pass      gh api repos/o/r/milestones -f title=M1
   ```
   ```bash
   # .github/hook-tests/guard.bats
   setup() { HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/guard.sh"; }
   run_guard() {  # $1: 명령, $2: description(선택)
     local json; json=$(printf '{"tool_name":"Bash","tool_input":{"command":%s,"description":%s},"cwd":"%s"}' \
       "$(printf '%s' "$1" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" \
       "$(printf '%s' "${2:-}" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" "${CWD:-/tmp/w}")
     printf '%s' "$json" | bash "$HOOK"
   }
   decision() { grep -o '"permissionDecision":"[a-z]*"' | cut -d'"' -f4; }

   @test "픽스처 표" {
     while IFS=$'\t' read -r want cmd _; do
       [[ -z $want || $want == \#* ]] && continue
       got=$(run_guard "$cmd" | decision); got=${got:-pass}
       [[ $got == "$want" ]] || { echo "기대 $want / 실제 $got : $cmd"; return 1; }
     done < "$BATS_TEST_DIRNAME/guard-cases.tsv"
   }

   @test "A2: main 위 git push, description에 docs/가 있어도 확인" {
     cd "$(mktemp -d)" && git init -q -b main && export CLAUDE_PROJECT_DIR=$PWD
     [[ $(run_guard "git push" "docs/STATUS.md 갱신 후 푸시" | decision) == ask ]]
   }
   ```
   - `gh pr merge` 분기는 `gh`를 가짜 스크립트로 바꿔(PATH 앞에 `fake-bin/gh` — 종료 코드 0/8/1과 출력 고정) CI 통과·진행 중·실패·CI 없음 4경우를 검사한다.
   - `check-turn.sh`는 임시 git 저장소에서 `checks.env`를 `TEST_CMD='false'`/`'true'`로 바꿔가며 "첫 실패 → block, 같은 상태 재실패 → 경고, `stop_hook_active` → 경고, 통과 → .last-pass 기록 후 재실행 생략"을 검사한다.
3. **CI**: `ubuntu-latest`와 `windows-latest`(Git Bash) 두 곳에서 `shellcheck .claude/hooks/*.sh`와 `bats .github/hook-tests`를 돌린다. Windows를 넣는 이유는 실제 사용 환경이고, 경로·줄바꿈(CRLF) 문제가 거기서만 드러나기 때문이다. `.gitattributes`에서 `*.sh text eol=lf`인지 함께 확인한다.
4. **성능 가드**: guard.sh는 모든 셸 명령마다 돈다. 픽스처 전체를 돌린 시간을 측정해 케이스당 평균이 기준(예: 50ms)을 넘으면 실패하게 한다. 빠른 통과 경로가 프로세스를 만들지 않는다는 설계를 지키기 위함이다.

**완료 기준**: 템플릿 저장소의 PR·push마다 template-ci가 돌고, A1~A3 케이스를 포함해 통과한다. 훅을 고치는 커밋에는 케이스 추가가 함께 들어간다(PR 템플릿 체크리스트에 템플릿 전용 항목 추가는 하지 않는다 — 프로젝트로 복사되므로. 대신 이 문서의 규칙으로 둔다).

---

## C. 측정

이 템플릿이 실제로 효과가 있는지를 보여줄 근거다. 데이터는 거슬러 올라가 만들 수 없으므로 **기능 개선보다 먼저 켜 둔다.**

### C1. 훅 이벤트 로그

- [ ] 완료

**방법**:
1. `lib.sh`에 `log_event <훅> <결과> <분류> [소요ms]`를 두고, 세 훅이 판정할 때마다 한 줄씩 남긴다.
   ```
   .claude/metrics/events.jsonl   (git 제외 — .gitignore에 추가)
   {"ts":"2026-11-24T10:12:03+09:00","hook":"guard","result":"ask","cat":"main-push"}
   {"ts":"...","hook":"check-turn","result":"block","cat":"test","ms":8120}
   {"ts":"...","hook":"check-turn","result":"pass","ms":7400}
   {"ts":"...","hook":"check-file","result":"lint-fail"}
   ```
   - 명령 원문은 남기지 않는다(비밀 값이 섞일 수 있음). 분류 이름만 남긴다.
   - 로그 쓰기 실패는 무시한다(훅 판정에 영향 주지 않음). 시간 측정은 `$EPOCHREALTIME`(bash 5)으로, 프로세스를 만들지 않는다.
   - 통과(pass)인 guard 판정은 남기지 않는다(양이 많고 의미가 적음). check-turn의 pass는 남긴다(실행 시간 지표).
2. 확인 창에서 사람이 허용했는지 거부했는지는 훅이 알 수 없다. 대신 PostToolUse에서 같은 명령이 실행됐는지로 추정할 수 있지만, 복잡도에 비해 가치가 낮으므로 하지 않는다.
3. 머신을 옮겨도 남게 하려면 `/wrap`이 세션 끝에 요약 한 줄을 STATUS.md 세션 로그에 붙인다(예: "검사 차단 2회·자가 수정 2회, 확인 창 3회"). 원본 로그는 로컬에만 둔다.

**완료 기준**: 새 프로젝트에서 일주일 쓰고 events.jsonl이 쌓이며, 훅 속도에 체감 차이가 없다(B1 성능 가드 통과).

### C2. 프로젝트 단위 지표 리포트

- [ ] 완료

**방법**: 템플릿 소유 스크립트 `.claude/hooks/report.sh`(또는 `/wrap`·`/review`의 한 단계)로 아래를 계산한다.

| 지표 | 계산 | 의미 |
|---|---|---|
| 자가 수정률 | check-turn block 뒤 다음 pass까지 사람 개입 없이 간 비율 | 검증 루프가 실제로 에이전트를 고치게 하는가 |
| 검사 차단 빈도 | 세션당 block 수 | 너무 잦으면 지시·컨텍스트 문제, 0이면 검사가 약하다는 신호 |
| 확인 창 빈도·분류 | guard ask를 분류별로 | 오탐이 많은 규칙을 찾아 다듬음 |
| Stop 검사 시간 | check-turn ms 중앙값·최대 | TEST_CMD를 좁힐지 판단 |
| CI 실패율 | `gh run list --json conclusion` 중 failure 비율 | 로컬 검사가 CI 실패를 미리 막는가 |
| 되돌림 비율 | `git log --grep` 되돌림/revert 커밋 ÷ 전체 | 계획 없이 덧칠한 작업이 줄었는가 |
| 계획 대비 이탈 | plans 문서의 "계획 변경" 기록 수 | Plan 단계의 질 |

- 프로젝트 몇 개(적용 전 이력이 있는 기존 프로젝트 포함)에서 적용 전/후 CI 실패율·되돌림 비율을 비교하면 가장 설득력 있는 근거가 된다. 기존 저장소의 git 이력으로 "적용 전" 값은 지금도 계산할 수 있다.

**완료 기준**: 두 개 이상 프로젝트의 리포트가 나오고, 결과를 바탕으로 규칙을 하나 이상 고친 기록이 있다(측정 → 개선 루프가 한 번 돈 것).

---

## D. 사용성

### D1. lite 모드

- [ ] 완료

**문제**: 대부분 1인용 소형 도구인데, 8단계 + PRD·ADR·마일스톤·이슈별 계획 승인을 모두 거치면 절차 비용이 결과물보다 커진다. 게이트마다 승인 왕복이 생긴다.

**방법**:
1. `STATUS.md` 현재 섹션에 `규모: lite / full`을 추가한다. `/kickoff`가 1단계 인터뷰 끝에 추천해 [승인 요청]한다.
2. 판정 기준(PROCESS.md에 표로): 앱 1개, 사용자 본인 또는 소수, 외부 서비스·결제·개인정보 없음, 예상 작업량이 작음 → lite. 하나라도 아니면 full. lite에서 시작해도 조건이 깨지면 full 전환을 [제안]한다.
3. lite에서 바뀌는 것:

| 단계 | full | lite |
|---|---|---|
| 1 | 아이디어 브리프 → PRD | 아이디어 브리프 한 장 (목표·비목표·MVP 기능 목록) |
| 2 | 항목별 ADR + 설계 문서 | ADR 하나 "스택·개발 환경·릴리즈" 묶음, overview 생략 |
| 1+2 게이트 | 따로 승인 | **한 번에 승인** |
| 3 | 마일스톤·GitHub 이슈 | `docs/plans/mvp.md` 체크리스트 하나, 이슈는 선택 |
| 4 | 이슈마다 계획 문서·승인 | 계획 승인은 처음 한 번, 이후 체크리스트 항목 단위로 진행. 범위를 벗어나는 것만 [질문] |
| 5~7 | 그대로 | 회고는 STATUS.md 세 줄 |

   훅·DoD·main 보호·릴리즈 게이트는 lite에서도 그대로 둔다(결정론적 장치는 비용이 거의 없음).
4. 각 단계 문서에 "lite일 때" 한 줄 문단을 추가하는 방식으로 구현한다(별도 문서 세트를 만들지 않음 — 이중 관리 방지).

**완료 기준**: 소형 프로젝트 하나를 lite로 시작해 첫 릴리즈까지 사람 승인 왕복 횟수가 full 대비 줄었음을 STATUS 세션 로그로 확인.

### D2. 응답 꼬리표 규칙 완화

- [ ] 완료

**문제**: "매 응답은 [질문]/[제안]/[승인 요청]/[요청]으로 끝낸다"는 진행 중에는 유용하지만, 단순 질의응답("이 함수 뭐 해?")에도 적용되면 군더더기가 된다.

**방법**: PROCESS.md 협업 규칙 1에 예외를 단다: "절차 진행과 무관한 질문에 답할 때, 또는 다음 행동이 직전 응답과 같을 때는 생략한다." CLAUDE.md의 "다른 요청으로 세션을 시작했다면…" 문장과 합쳐 한 곳에 둔다.

### D3. 컨텍스트 예산

- [ ] 완료

**문제**: 세션마다 자동 로드되는 CLAUDE.md + AGENTS.md + PROCESS.md + STATUS.md가 현재 약 12KB다. 프로젝트가 진행되면 AGENTS.md(Gotchas·제약)와 STATUS.md(결정·가정 표)가 계속 자란다.

**방법**:
1. 예산을 정한다: 자동 로드 합계 상한(예: 20KB)과 파일별 상한. B1의 template-ci에서 템플릿 상태의 크기를 검사하고, 프로젝트에서는 `/wrap`이 상한 초과 시 정리를 [제안]한다.
2. 자라는 부분의 배출구를 둔다.
   - STATUS.md 결정 기록이 일정 개수를 넘으면 오래된 것을 `docs/decisions-log.md`(자동 로드 안 함)로 옮긴다. 세션 로그 10개 제한과 같은 방식.
   - AGENTS.md Gotchas가 특정 영역에 몰리면 그 폴더의 하위 CLAUDE.md/AGENTS.md로 옮긴다(해당 폴더 작업 시에만 로드됨).
3. `/context`로 실제 토큰 사용량을 가끔 확인해 이 문서에 기록한다.

---

## E. 확장

### E1. git 훅으로 같은 검사 공유

- [ ] 완료

**문제**: 안전장치가 Claude Code 훅에만 있다. AGENTS.md를 읽는 다른 에이전트(Codex 등)나 사람이 터미널·IDE에서 직접 하는 push·커밋은 검사를 거치지 않는다. git-flow.md도 "Claude를 거치지 않은 push·병합은 막지 못한다"고 적고 있다. 비공개 저장소라 GitHub 보호 규칙도 못 쓴다.

**방법**:
1. `.githooks/pre-commit`(빠른 린트 — `checks.env`의 FORMAT/LINT를 staged 파일에), `.githooks/pre-push`(main/태그 push 시 확인 메시지 + TEST_CMD)를 두고 `git config core.hooksPath .githooks`를 0단계에서 설정한다. 설정은 `checks.env`를 그대로 읽어 명령을 한 곳에서 관리한다.
2. 사람이 의도적으로 우회(`--no-verify`)할 수 있는 것은 그대로 둔다. 목적은 실수 방지다. 에이전트에 대해서는 AGENTS.md 규칙 8(우회 금지)이 이미 있다.
3. 템플릿 소유 파일 목록에 `.githooks/*`를 추가한다.

### E2. 템플릿 설계 결정 기록

- [ ] 완료

**문제**: "왜 deny 대신 ask인가", "왜 같은 실패는 한 번만 막나", "왜 Stop 훅에서 테스트를 도나" 같은 결정이 커밋 메시지에 흩어져 있고, 겪은 문제(예: 무한 반복, Git Bash 미탐지로 셸 전체가 막힌 일)는 기록이 없다. 시간이 지나면 본인도 이유를 잊는다.

**방법**: 템플릿 전용 `.github/decisions/`에 ADR 형식(맥락·결정·대안·결과)으로 사후 기록한다. 후보:
- 0001 지시문과 훅의 역할 분리
- 0002 위험 명령은 차단 대신 확인(ask), CI 실패 병합만 거부
- 0003 Stop 훅 검증 루프와 반복 방지(같은 실패 1회, stop_hook_active)
- 0004 jq 없이 bash 내장 정규식으로 판정 (Windows 기본 환경, 명령마다 실행되는 속도)
- 0005 AGENTS.md 공용 + CLAUDE.md import 구조
- 0006 템플릿 업데이트를 copier 방식(버전 기록 + 3-way 병합)으로, 플러그인 분리
- 0007 비공개 저장소에서 main 보호를 로컬 훅으로 대신

새 결정부터는 템플릿 변경 커밋과 함께 쓴다.

---

## F. 공개 전환 시

### F1. 공개 전환 체크리스트

- [ ] 완료

1. **개인 정보·환경 흔적 제거**: `tools/scripts/new-project.ps1` 예시의 로컬 사용자 경로, 저장소 곳곳의 계정 이름 하드코딩(`huny4daniel/huny4daniels-TEMPLATE`)을 점검한다. 남들도 쓰게 할 거면 저장소 이름을 `.template-version`의 `repo=` 하나에서 읽도록 바꾼다.
2. **README 보강**: 비슷한 도구(GitHub Spec Kit, BMAD Method, Kiro의 spec 방식 등)와 비교표 — 무엇이 같고 무엇이 다른지(이 템플릿의 차별점: 결정론적 훅 계층, 업데이트 가능한 템플릿, 사람 게이트 표). 비교는 공개 시점의 최신 상태로 다시 조사한다.
3. **근거 첨부**: C2 리포트 요약(적용 전/후 지표)을 README에 싣는다. 숫자가 없으면 이 항목은 미룬다.
4. **예시 프로젝트 연결**: 이 템플릿으로 처음부터 만든 공개 저장소 하나 — PRD·ADR·plans·STATUS 이력이 실제로 채워진 것. 공개해도 되는 소형 프로젝트를 lite 모드로 하나 진행하면 된다.
5. **설계 이야기**: E2의 결정 기록 중 겪은 문제가 있는 것 2~3개를 골라 "문제 → 시도 → 결과"로 짧게 쓴다.
6. 플러그인 저장소도 함께 공개하고, 설치 안내에서 "비공개라 gh auth 필요" 문구를 지운다.

---

## 변경 시 함께 고칠 곳

템플릿 전용 파일을 추가·삭제하면 아래를 모두 고친다.

- `docs/process/template-update.md` 파일 소유 구분의 "제외" 행
- `docs/process/00-init.md`의 템플릿 전용 파일 삭제 안내
- `tools/scripts/new-project.ps1`의 robocopy 제외 목록
- 플러그인 저장소 `plugins/project-process/commands/adopt.md` 새 프로젝트 모드 복사 제외 목록 (+ `plugin.json` 버전)
- `.github/README.md` 템플릿 관리 섹션
