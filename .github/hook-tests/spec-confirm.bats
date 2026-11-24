#!/usr/bin/env bats
# spec-confirm.sh (ROADMAP H3) 회귀 테스트 — 템플릿 전용

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo main)
  cd "$CLAUDE_PROJECT_DIR"
  mkdir -p docs
  cat > docs/SPEC.md <<'EOF'
### F-03 저장 — Must · In Progress

- **F-03.1** 정상 저장 [확정]
- **F-03.2** 쓰기 권한 없음 [제안]
- **F-03.3** 자동 저장 주기 [미정] — 고정할지
EOF
  SPEC="$CLAUDE_PROJECT_DIR/docs/SPEC.md"
}

edit() {  # edit <파일> <old> <new>
  printf '{"tool_name":"Edit","tool_input":{"file_path":%s,"old_string":%s,"new_string":%s}}' \
    "$(json_str "$1")" "$(json_str "$2")" "$(json_str "$3")" | bash "$HOOKS/spec-confirm.sh"
}
write() {  # write <파일> <내용>
  printf '{"tool_name":"Write","tool_input":{"file_path":%s,"content":%s}}' "$(json_str "$1")" "$(json_str "$2")" \
    | bash "$HOOKS/spec-confirm.sh"
}

@test "spec-confirm: proposed -> confirmed asks, naming the scenario" {
  out=$(edit "$SPEC" '- **F-03.2** 쓰기 권한 없음 [제안]' '- **F-03.2** 쓰기 권한 없음 [확정]')
  expect ask "$(decision <<< "$out")" "판정"
  [[ $out == *"F-03.2(제안→확정)"* ]] || { echo "$out"; return 1; }
}

@test "spec-confirm: undecided -> confirmed asks" {
  out=$(edit "$SPEC" '- **F-03.3** 자동 저장 주기 [미정] — 고정할지' '- **F-03.3** 자동 저장 주기 [확정] — 5분마다')
  expect ask "$(decision <<< "$out")" "판정"
}

@test "spec-confirm: several confirmations in one edit -> one dialog listing all" {
  out=$(edit "$SPEC" $'- **F-03.2** 쓰기 권한 없음 [제안]\n- **F-03.3** 자동 저장 주기 [미정] — 고정할지' \
                     $'- **F-03.2** 쓰기 권한 없음 [확정]\n- **F-03.3** 자동 저장 주기 [확정] — 5분')
  [[ $out == *"F-03.2(제안→확정), F-03.3(미정→확정)"* ]] || { echo "$out"; return 1; }
  expect 1 "$(grep -c permissionDecision <<< "$out")" "창은 하나"
}

@test "spec-confirm: other edits pass (wording, new proposal, already confirmed)" {
  expect pass "$(edit "$SPEC" '정상 저장 [확정]' '정상적으로 저장 [확정]' | decision)" "확정 문구 수정"
  expect pass "$(edit "$SPEC" '- **F-03.3**' $'- **F-03.4** 용량 초과 [제안]\n- **F-03.3**' | decision)" "새 제안 추가"
  expect pass "$(edit "$SPEC" '[제안]' '[미정]' | decision)" "제안을 미정으로"
}

@test "spec-confirm: whole-file Write that confirms a proposal asks" {
  new=$(sed 's/쓰기 권한 없음 \[제안\]/쓰기 권한 없음 [확정]/' docs/SPEC.md)
  expect ask "$(write "$SPEC" "$new" | decision)" "Write"
}

@test "spec-confirm: edit without the scenario ID is still caught" {
  # Claude가 ID 없이 표시 부분만 바꾸는 경우 — 파일에 적용한 결과로 판정해야 잡힌다
  out=$(edit "$SPEC" '쓰기 권한 없음 [제안]' '쓰기 권한 없음 [확정]')
  expect ask "$(decision <<< "$out")" "ID 없는 조각"
  [[ $out == *"F-03.2(제안→확정)"* ]] || { echo "$out"; return 1; }
}

@test "spec-confirm: replace_all confirming every proposal asks" {
  local d
  d=$(printf '{"tool_name":"Edit","tool_input":{"file_path":%s,"old_string":"[제안]","new_string":"[확정]","replace_all":true}}' "$(json_str "$SPEC")" \
      | bash "$HOOKS/spec-confirm.sh" | decision)
  expect ask "$d" "replace_all"
}

@test "spec-confirm: other files are ignored" {
  mkdir -p src
  expect pass "$(edit "$CLAUDE_PROJECT_DIR/src/a.md" '- **F-03.2** x [제안]' '- **F-03.2** x [확정]' | decision)" "다른 파일"
}

@test "spec-confirm: Windows-style path to SPEC.md is recognized" {
  [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]] || skip "Windows 전용"
  win=$(cygpath -w "$SPEC")
  expect ask "$(edit "$win" '쓰기 권한 없음 [제안]' '쓰기 권한 없음 [확정]' | decision)" "Windows 경로"
}
