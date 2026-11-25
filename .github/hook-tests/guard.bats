#!/usr/bin/env bats
# guard.sh (PreToolUse) 회귀 테스트

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo feature/base)
}

# 픽스처 표 (guard-cases.tsv)
@test "fixture table (guard-cases.tsv)" {
  local fails=0 want cmd got
  while IFS=$'\t' read -r want cmd _; do
    [[ -z $want || $want == \#* ]] && continue
    got=$(run_guard "$cmd" | decision)
    if [[ $got != "$want" ]]; then echo "기대 $want / 실제 $got : $cmd" >&2; fails=$((fails + 1)); fi
  done < "$BATS_TEST_DIRNAME/guard-cases.tsv"
  [[ $fails -eq 0 ]]
}

# main 브랜치에서 인자 없는 git push → ask
@test "bare git push on main -> ask" {
  CLAUDE_PROJECT_DIR=$(new_repo main)
  expect ask "$(run_guard "git push" | decision)" "git push (main)"
}

# 작업 브랜치에서 인자 없는 git push → pass
@test "bare git push on work branch -> pass" {
  expect pass "$(run_guard "git push" | decision)" "git push (feature/base)"
}

# PowerShell 도구도 같은 판정
@test "PowerShell tool gets the same decision" {
  TOOL=PowerShell
  expect ask "$(run_guard "Remove-Item -Recurse -Force dist" | decision)" "PowerShell Remove-Item"
}

# ---------- A2: 명령(tool_input.command)만 판정한다 ----------

# A2 놓침: main에서 git push, description에 docs/가 있어도 ask
@test "A2 miss: git push on main with docs/ in description -> ask" {
  CLAUDE_PROJECT_DIR=$(new_repo main)
  expect ask "$(run_guard "git push" "docs/STATUS.md 갱신 후 푸시" | decision)" "description의 docs/"
}

# A2 오탐: cwd·transcript 경로에 main 폴더가 있어도 작업 브랜치 push는 pass
@test "A2 false positive: main in cwd/transcript path, work-branch push -> pass" {
  CWD='C:\work\main\app'
  expect pass "$(run_guard "git push origin feature/x" | decision)" "cwd의 main"
}

# A2 오탐: description에 main·위험 명령 문구가 있어도 명령이 안전하면 pass
@test "A2 false positive: main or risky words only in description -> pass" {
  expect pass "$(run_guard "git push origin feature/x" "main과 충돌 해결 후 push" | decision)" "description의 main"
  expect pass "$(run_guard "ls -la" "rm -rf build 전에 목록 확인" | decision)" "description의 rm -rf"
}

# A2 오탐: 다른 명령에 main이 있어도 push 대상이 작업 브랜치면 pass
@test "A2 false positive: main in another command, push target is work branch -> pass" {
  expect pass "$(run_guard "git log main..HEAD && git push origin feature/x" | decision)" "log main"
}

# A2: push 대상 refspec 판정
@test "A2: push target refspec decisions" {
  expect ask "$(run_guard "git push origin feature/x:main" | decision)" "src:main"
  expect ask "$(run_guard "git push origin HEAD:refs/heads/main" | decision)" "HEAD:refs/heads/main"
  expect ask "$(run_guard "GIT PUSH ORIGIN MAIN" | decision)" "대문자 MAIN"
  expect ask "$(run_guard "git push --all origin" | decision)" "--all"
  expect ask "$(run_guard "git push origin feature/x && git push origin main" | decision)" "복합 명령"
  expect pass "$(run_guard "git push origin HEAD" | decision)" "HEAD (feature/base)"
  expect pass "$(run_guard "git -C sub push origin feature/x" | decision)" "-C"
}

# A2: main에서 git push origin HEAD → ask
@test "A2: git push origin HEAD on main -> ask" {
  CLAUDE_PROJECT_DIR=$(new_repo main)
  expect ask "$(run_guard "git push origin HEAD" | decision)" "HEAD (main)"
}

# A2: upstream이 main인 작업 브랜치에서 인자 없는 git push → ask
@test "A2: bare git push on work branch whose upstream is main -> ask" {
  local remote; remote=$(mktemp -d)
  git init -q --bare "$remote"
  git -C "$CLAUDE_PROJECT_DIR" remote add origin "$remote"
  git -C "$CLAUDE_PROJECT_DIR" push -q origin HEAD:main
  git -C "$CLAUDE_PROJECT_DIR" branch -q -u origin/main
  expect ask "$(run_guard "git push" | decision)" "upstream origin/main"
}

# ---------- gh pr merge: CI 상태 확인 ----------

merge_case() {  # $1 기대값  $2 FAKE_GH_MODE  $3 명령
  PATH="$BATS_TEST_DIRNAME/fake-bin:$PATH" FAKE_GH_MODE=$2 run_guard "$3" | decision
}

# gh pr merge: CI 통과 → ask
@test "gh pr merge: CI passed -> ask" {
  expect ask "$(merge_case ask pass 'gh pr merge 5 --squash')" pass
}
# gh pr merge: CI 실패 → deny
@test "gh pr merge: CI failed -> deny" {
  expect deny "$(merge_case deny fail 'gh pr merge 5 --squash')" fail
}
# gh pr merge: CI 진행 중 → deny
@test "gh pr merge: CI pending -> deny" {
  expect deny "$(merge_case deny pending 'gh pr merge --squash')" pending
}
# gh pr merge: CI 없음 → ask
@test "gh pr merge: no CI -> ask" {
  expect ask "$(merge_case ask nochk 'gh pr merge 7')" nochk
}
# gh pr merge: PR 없음·인증 오류 → ask (막지 않음)
@test "gh pr merge: no PR or auth error -> ask (not blocked)" {
  expect ask "$(merge_case ask nopr 'gh pr merge')" nopr
  expect ask "$(merge_case ask noauth 'gh pr merge 5')" noauth
}
# gh pr merge: 대상(번호·브랜치)을 gh pr checks에 넘긴다
@test "gh pr merge: passes target (number/branch) to gh pr checks" {
  export FAKE_GH_LOG; FAKE_GH_LOG=$(mktemp)
  merge_case deny fail 'gh pr merge 12 --squash' >/dev/null
  merge_case deny fail 'gh pr merge feature/1-x' >/dev/null
  merge_case deny fail 'gh pr merge --squash' >/dev/null
  expect "pr checks 12|pr checks feature/1-x|pr checks" "$(paste -sd'|' "$FAKE_GH_LOG")" "gh 호출 인자"
}
# REST 병합(gh pr merge 실패 뒤 우회): 같은 CI 검사를 거친다
@test "gh api pulls/N/merge (write): same CI check as gh pr merge" {
  expect ask "$(merge_case ask pass 'gh api -X PUT repos/o/r/pulls/3/merge -f merge_method=squash')" pass
  expect deny "$(merge_case deny fail 'gh api -X PUT repos/o/r/pulls/3/merge -f merge_method=squash')" fail
  expect deny "$(merge_case deny pending 'gh api --method PUT /repos/o/r/pulls/3/merge')" pending
  export FAKE_GH_LOG; FAKE_GH_LOG=$(mktemp)
  merge_case deny fail 'gh api -X PUT repos/o/r/pulls/42/merge' >/dev/null
  expect "pr checks 42" "$(cat "$FAKE_GH_LOG")" "gh 호출 인자"
}
# REST 병합 여부 조회(GET)는 병합이 아니다
@test "gh api pulls/N/merge (read): pass" {
  expect pass "$(merge_case pass fail 'gh api repos/o/r/pulls/3/merge')" "GET"
}

# ---------- 성능: 모든 셸 명령마다 실행되므로 빠른 통과 경로가 프로세스를 만들지 않아야 함 ----------

# 성능: 케이스당 평균 실행 시간이 기준 이하
@test "perf: average time per case within limit" {
  # 기준(ms): bash 자체 기동 비용이 OS마다 달라 따로 둔다. GUARD_PERF_MS로 덮어쓸 수 있다.
  local limit=${GUARD_PERF_MS:-50}
  [[ ${OS:-} == Windows_NT || $(uname -s) == MINGW* || $(uname -s) == MSYS* || $(uname -s) == CYGWIN* ]] && limit=${GUARD_PERF_MS:-250}
  local cmds=("ls -la" "python -m pytest -q" "npm test" "git status" "git push origin feature/1-x") n start end avg best=
  # CI 러너의 일시적인 속도 편차로 실패하지 않도록 세 번 재고 가장 빠른 값으로 판정한다
  for _ in 1 2 3; do
    n=0; start=$EPOCHREALTIME
    for _ in 1 2 3 4; do for c in "${cmds[@]}"; do run_guard "$c" >/dev/null; n=$((n + 1)); done; done
    end=$EPOCHREALTIME
    avg=$(( (${end//[.,]/} - ${start//[.,]/}) / 1000 / n ))
    [[ -z $best || $avg -lt $best ]] && best=$avg
    [[ $best -le $limit ]] && break
  done
  echo "평균 ${best}ms (기준 ${limit}ms, 세 번 중 가장 빠른 값)" >&2
  [[ $best -le $limit ]]
}
