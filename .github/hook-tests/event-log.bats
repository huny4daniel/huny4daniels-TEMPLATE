#!/usr/bin/env bats
# 훅 이벤트 로그 (ROADMAP C1) 회귀 테스트 — 템플릿 전용

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo main)
  cd "$CLAUDE_PROJECT_DIR"
  LOG=.claude/metrics/events.jsonl
  export HOOK_EVENT_LOG=1
}

guard_with_session() {
  printf '{"session_id":"sess-1","tool_name":"Bash","tool_input":{"command":%s,"description":"x"}}' "$(json_str "$1")" \
    | bash "$HOOKS/guard.sh" | decision
}

@test "event-log: guard ask is logged with category, without command text" {
  expect ask "$(guard_with_session 'git push origin main')" "판정"
  expect ask "$(guard_with_session 'cat .env')" "판정"
  [[ -f $LOG ]] || { echo "로그 없음"; return 1; }
  expect 2 "$(wc -l < "$LOG" | tr -d ' ')" "줄 수"
  grep -q '"session":"sess-1","hook":"guard","result":"ask","cat":"main 반영"' "$LOG" || { cat "$LOG"; return 1; }
  ! grep -q 'git push\|\.env' "$LOG" || { echo "명령 원문이 남았다"; cat "$LOG"; return 1; }
}

@test "event-log: passing commands are not logged" {
  expect pass "$(guard_with_session 'git status')" "판정"
  [[ ! -s $LOG ]] || { cat "$LOG"; return 1; }
}

@test "event-log: HOOK_EVENT_LOG=0 disables logging" {
  HOOK_EVENT_LOG=0 guard_with_session 'git push origin main' >/dev/null
  [[ ! -e $LOG ]] || { cat "$LOG"; return 1; }
}

@test "event-log: logging failure does not change the decision" {
  mkdir -p .claude && : > .claude/metrics   # 디렉터리 자리에 파일이 있어 기록할 수 없다
  expect ask "$(guard_with_session 'git push origin main')" "기록 실패해도 판정은 그대로"
}

@test "event-log: check-turn logs block with kinds and ms, then pass" {
  mkdir -p .claude/hooks src
  cp "$HOOKS"/*.sh .claude/hooks/
  cat > .claude/hooks/checks.env <<'EOF'
FILE_PATTERN='\.py$'
LINT_CMD=''
TYPECHECK_CMD=''
TEST_CMD='! grep -rq FAILTEST src'
EOF
  printf '.claude/hooks/.last-*\n.claude/metrics/\n' > .gitignore
  echo 'x = 1' > src/a.py
  git add -A && git -c user.email=t@t -c user.name=t commit -qm base
  echo '# FAILTEST' >> src/a.py
  expect block "$(stop_input false | bash .claude/hooks/check-turn.sh | decision)" "첫 실패"
  echo 'y = 2' > src/a.py
  expect pass "$(stop_input false | bash .claude/hooks/check-turn.sh | decision)" "고친 뒤"
  grep -qE '"hook":"check-turn","result":"block","cat":"테스트","ms":[0-9]+' "$LOG" || { cat "$LOG"; return 1; }
  grep -qE '"hook":"check-turn","result":"pass","ms":[0-9]+' "$LOG" || { cat "$LOG"; return 1; }
}

@test "event-log: metrics.sh summarizes counts and self-fix ratio" {
  mkdir -p .claude/metrics
  local today; printf -v today '%(%Y-%m-%d)T' -1
  cat > "$LOG" <<EOF
{"ts":"${today}T10:00:00+0900","session":"s1","hook":"guard","result":"ask","cat":"main 반영"}
{"ts":"${today}T10:02:00+0900","session":"s1","hook":"check-turn","result":"block","cat":"테스트,spec 커버리지","ms":5000}
{"ts":"${today}T10:03:00+0900","session":"s1","hook":"check-turn","result":"pass","ms":800}
{"ts":"${today}T10:04:00+0900","session":"s2","hook":"check-turn","result":"block","cat":"린트","ms":300}
{"ts":"2000-01-01T10:05:00+0900","session":"s0","hook":"guard","result":"deny","cat":"CI 실패"}
EOF
  out=$(bash "$HOOKS/metrics.sh")
  for want in "(오늘)" "확인 창 1 (main 반영 1) · 거부 0" "차단 2" "spec 커버리지 1" "차단 뒤 같은 세션에서 통과 1/2" "중앙값 800ms"; do
    [[ $out == *"$want"* ]] || { echo "없음: $want"$'\n'"$out"; return 1; }
  done
  [[ $(bash "$HOOKS/metrics.sh" all) == *"거부 1"* ]] || { bash "$HOOKS/metrics.sh" all; return 1; }
}
