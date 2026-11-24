# 훅 테스트 공용 도우미 (템플릿 전용 — 새 프로젝트로 복사되지 않음)
# bats에서 `load helpers`로 불러온다. bats 전용 기능(run, $output 등)은 쓰지 않는다.

HOOKS="$BATS_TEST_DIRNAME/../../.claude/hooks"

# json_str <문자열>: JSON 문자열 리터럴로 인코딩 (python·jq 없이)
json_str() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; s=${s//$'\r'/\\r}
  printf '"%s"' "$s"
}

# pre_tool_input <명령> [description]: Claude Code가 PreToolUse 훅에 보내는 형태의 JSON
#   CWD 환경 변수로 cwd·transcript_path를 바꿀 수 있다 (명령 외 필드 오판 테스트용).
pre_tool_input() {
  local cwd="${CWD:-/tmp/work}"
  printf '{"session_id":"test","transcript_path":%s,"cwd":%s,"permission_mode":"default","hook_event_name":"PreToolUse","tool_name":%s,"tool_input":{"command":%s,"description":%s,"timeout":120000}}' \
    "$(json_str "$cwd/.claude/transcript.jsonl")" "$(json_str "$cwd")" "$(json_str "${TOOL:-Bash}")" \
    "$(json_str "$1")" "$(json_str "${2:-}")"
}

# post_edit_input <파일 경로>: PostToolUse(Edit) 훅 입력
post_edit_input() {
  printf '{"session_id":"test","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":%s,"old_string":"a","new_string":"b"},"tool_response":{"filePath":%s,"success":true}}' \
    "$(json_str "$1")" "$(json_str "$1")"
}

# stop_input <true|false>: Stop 훅 입력
stop_input() {
  printf '{"session_id":"test","hook_event_name":"Stop","stop_hook_active":%s}' "${1:-false}"
}

run_guard() { pre_tool_input "$1" "${2:-}" | bash "$HOOKS/guard.sh"; }

# 표준 입력의 훅 출력에서 판정을 꺼낸다. 출력이 없으면 pass.
decision() {
  local out d=""
  out=$(cat)
  [[ $out =~ \"permissionDecision\":\"([a-z]+)\" ]] && d=${BASH_REMATCH[1]}
  [[ $out =~ \"decision\":\"([a-z]+)\" ]] && d=${BASH_REMATCH[1]}
  [[ -z $d && $out == *'"systemMessage"'* ]] && d=warn
  printf '%s' "${d:-pass}"
}

# new_repo [브랜치]: 빈 커밋 하나가 있는 임시 git 저장소를 만들고 경로를 출력
new_repo() {
  local d
  d=$(mktemp -d)
  git -C "$d" init -q -b "${1:-main}"
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf '%s' "$d"
}

# expect <기대값> <실제값> <설명>: 다르면 메시지를 남기고 실패
expect() {
  [[ $1 == "$2" ]] || { echo "기대 $1 / 실제 $2 : $3" >&2; return 1; }
}
