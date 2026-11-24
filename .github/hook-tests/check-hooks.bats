#!/usr/bin/env bats
# check-file.sh (PostToolUse) · check-turn.sh (Stop) 회귀 테스트

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo main)
  cd "$CLAUDE_PROJECT_DIR"
  mkdir -p .claude/hooks src
  cp "$HOOKS"/*.sh .claude/hooks/
  # 가짜 린터: BAD가 있으면 실패 / 가짜 테스트: FAILTEST가 있으면 실패, 실행 횟수 기록
  cat > lint.sh <<'EOF'
#!/usr/bin/env bash
rc=0; for f in "$@"; do grep -Hn 'BAD' "$f" && rc=1; done; exit $rc
EOF
  cat > test.sh <<'EOF'
#!/usr/bin/env bash
echo run >> .test-runs
[ "$1" = "-m" ] && [ "$2" = "not slow" ] || { echo "ARGS BROKEN: [$1] [$2]"; exit 1; }
if grep -rq 'FAILTEST' src; then echo "test FAILED"; exit 1; fi
echo ok
EOF
  cat > .claude/hooks/checks.env <<'EOF'
FILE_PATTERN='\.py$'
FORMAT_CMD=''
LINT_CMD='bash lint.sh'
TYPECHECK_CMD=''
TEST_CMD='bash test.sh -m "not slow" && echo chained'
EOF
  printf '.claude/hooks/.last-*\n.test-runs\n' > .gitignore
  echo 'x = 1' > src/a.py
  git add -A && git -c user.email=t@t -c user.name=t commit -qm base
}

turn() { stop_input "$1" | bash .claude/hooks/check-turn.sh | decision; }
runs() { [[ -f .test-runs ]] && wc -l < .test-runs | tr -d ' ' || echo 0; }

# ---------- check-turn.sh ----------

# check-turn: 코드 변경 없음 → 검사 안 함
@test "check-turn: no code change -> no checks" {
  expect pass "$(turn false)" "변경 없음"
  expect 0 "$(runs)" "테스트 실행 횟수"
}

# check-turn: 통과 → .last-pass 기록, 같은 상태는 재실행 생략
@test "check-turn: pass -> .last-pass saved, same state skipped" {
  echo 'y = 2' >> src/a.py
  expect pass "$(turn false)" "첫 통과"
  [[ -f .claude/hooks/.last-pass ]]
  expect pass "$(turn false)" "재실행"
  expect 1 "$(runs)" "같은 상태 재실행 생략"
}

# check-turn: 첫 실패 → block, 같은 상태 재실패 → warn
@test "check-turn: first failure -> block, same failure again -> warn" {
  echo '# FAILTEST' >> src/a.py
  expect block "$(turn false)" "첫 실패"
  expect warn "$(turn false)" "같은 실패"
}

# check-turn: 실패 내용이 바뀌면 다시 block
@test "check-turn: changed failure -> block again" {
  echo '# FAILTEST' >> src/a.py
  turn false >/dev/null
  echo '# FAILTEST 2' >> src/a.py
  expect block "$(turn false)" "바뀐 실패"
}

# check-turn: stop_hook_active → warn (무한 반복 방지)
@test "check-turn: stop_hook_active -> warn (no infinite loop)" {
  echo '# FAILTEST' >> src/a.py
  expect warn "$(turn true)" "stop_hook_active"
}

# check-turn: 고친 뒤 같은 실패가 재발하면 다시 block
@test "check-turn: same failure after a fix -> block again" {
  echo 'y = 2' >> src/a.py; turn false >/dev/null
  echo '# FAILTEST' >> src/a.py; turn false >/dev/null
  sed -i '/FAILTEST/d' src/a.py
  expect pass "$(turn false)" "고침"
  echo '# FAILTEST' >> src/a.py
  expect block "$(turn false)" "재발"
}

# check-turn: 셸로 만든 파일의 린트 오류도 잡는다
@test "check-turn: lint errors in files written by shell" {
  printf 'BAD = 1\n' > src/b.py
  expect block "$(turn false)" "린트"
}

# check-turn: 캐시 파일이 git에 추적돼도 같은 실패를 새 실패로 보지 않는다
@test "check-turn: tracked cache files do not turn the same failure into a new one" {
  : > .gitignore
  echo '# FAILTEST' >> src/a.py
  turn false >/dev/null
  git add -f .claude/hooks/.last-fail && git -c user.email=t@t -c user.name=t commit -qm cache
  echo '# FAILTEST 2' >> src/a.py
  expect block "$(turn false)" "첫 실패"
  expect warn "$(turn false)" "같은 실패"
}

# check-turn: 설정이 비어 있으면 아무것도 하지 않음
@test "check-turn: empty config does nothing" {
  printf "FILE_PATTERN='\\\\.py\$'\nLINT_CMD=''\nTYPECHECK_CMD=''\nTEST_CMD=''\n" > .claude/hooks/checks.env
  echo '# FAILTEST' >> src/a.py
  expect pass "$(turn false)" "빈 설정"
}

# ---------- check-file.sh ----------

edit() { post_edit_input "$1" | bash .claude/hooks/check-file.sh >/dev/null 2>&1; echo $?; }

# check-file: 린트 오류 → exit 2, 고치면 0
@test "check-file: lint error -> exit 2, fixed -> 0" {
  echo 'BAD = 1' >> src/a.py
  expect 2 "$(edit "$PWD/src/a.py")" "린트 오류"
  sed -i '/BAD/d' src/a.py
  expect 0 "$(edit "$PWD/src/a.py")" "고침"
}

# check-file: 대상이 아닌 파일·없는 파일은 건너뜀
@test "check-file: non-target and missing files are skipped" {
  echo BAD > notes.md
  expect 0 "$(edit "$PWD/notes.md")" "대상 아님"
  expect 0 "$(edit "$PWD/src/none.py")" "없는 파일"
}

# check-file: 공백이 들어간 경로
@test "check-file: path with spaces" {
  mkdir -p "src/my dir"; echo BAD > "src/my dir/c.py"
  expect 2 "$(edit "$PWD/src/my dir/c.py")" "공백 경로"
}

# ---------- A3: file_path JSON 파싱 ----------

is_windows() { [[ $(uname -s) == MINGW* || $(uname -s) == MSYS* || $(uname -s) == CYGWIN* ]]; }

# A3: 한글·공백이 들어간 경로
@test "A3: path with Korean and spaces" {
  mkdir -p "src/한글 폴더"; echo BAD > "src/한글 폴더/모듈 1.py"
  expect 2 "$(edit "$PWD/src/한글 폴더/모듈 1.py")" "한글·공백 경로"
}

# A3: 따옴표가 들어간 경로 (Windows는 파일 이름에 따옴표 불가 → 건너뜀)
@test "A3: path with quotes (skipped on Windows)" {
  is_windows && skip "Windows 파일 이름에는 따옴표를 쓸 수 없음"
  mkdir -p 'src/say "hi"'; echo BAD > 'src/say "hi"/q.py'
  expect 2 "$(edit "$PWD/src/say \"hi\"/q.py")" "따옴표 경로"
}

# A3: JSON 이스케이프된 Windows 경로 (C:\\a\\b)
@test "A3: JSON-escaped Windows path" {
  is_windows || skip "Windows 경로 변환은 Git Bash에서만"
  mkdir -p "src/win dir"; echo BAD > "src/win dir/w.py"
  expect 2 "$(edit "$(cygpath -w "$PWD/src/win dir/w.py")")" "Windows 경로"
}

# A3: json_field 이스케이프 처리
@test "A3: json_field unescaping" {
  source "$HOOKS/lib.sh"
  input='{"a":"x","description":"\"command\": \"rm -rf /\"","command":"echo \"q\" \\ \/ 한글\tt"}'
  expect $'echo "q" \\ / 한글\tt' "$(json_field command)" "디코딩"
  input='{"file_path": "C:\\work\\a \"b\".py"}'
  expect 'C:\work\a "b".py' "$(json_field file_path)" "공백 있는 키 구분자·따옴표"
  input='{"x":"y"}'
  ! json_field command
}

# A3: json_bool
@test "A3: json_bool" {
  source "$HOOKS/lib.sh"
  input='{"stop_hook_active": true}'; json_bool stop_hook_active
  input='{"stop_hook_active":false,"m":"\"stop_hook_active\": true"}'; ! json_bool stop_hook_active
}
