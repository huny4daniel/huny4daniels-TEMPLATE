#!/usr/bin/env bash
# Stop 훅: Claude가 응답을 마치려 할 때, 코드가 바뀌었으면 타입 체크와 단위 테스트를 돌린다.
# 실패하면 응답 종료를 막고(decision: block) 실패 내용을 Claude에게 돌려 고치게 한다.
# - 바뀐 코드 파일이 없거나, 같은 상태로 이미 통과했으면 건너뛴다 (.claude/hooks/.last-pass).
# - 훅 때문에 이어진 응답(stop_hook_active)에서 또 실패하면 막지 않고 경고만 띄운다 (무한 반복 방지).
# 설정: .claude/hooks/checks.env

input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-.}"
conf="$root/.claude/hooks/checks.env"
[ -f "$conf" ] || exit 0
# shellcheck disable=SC1090
. "$conf"
[ -n "$TYPECHECK_CMD$TEST_CMD" ] || exit 0
cd "$root" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

changed="$(git status --porcelain --untracked-files=all 2>/dev/null | cut -c4- | grep -E -- "$FILE_PATTERN")"
[ -n "$changed" ] || exit 0

state="$( { git diff HEAD 2>/dev/null; printf '%s\n' "$changed" | while IFS= read -r f; do [ -f "$f" ] && cat "$f"; done; } | cksum)"
last="$root/.claude/hooks/.last-pass"
[ -f "$last" ] && [ "$(cat "$last")" = "$state" ] && exit 0

json_escape() {
  sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//g' \
    | awk 'BEGIN{ORS="\\n"} {print}'
}

report=""
run() {
  label="$1"; cmd="$2"
  [ -n "$cmd" ] || return 0
  out="$($cmd 2>&1)"
  if [ $? -ne 0 ]; then
    report="${report}[${label} 실패] ${cmd}
$(printf '%s\n' "$out" | tail -n 30)
"
  fi
}
run "타입 체크" "$TYPECHECK_CMD"
run "테스트" "$TEST_CMD"

if [ -z "$report" ]; then
  printf '%s' "$state" > "$last"
  exit 0
fi

if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  printf '{"systemMessage":"%s"}\n' "$(printf '자동 검사 실패가 남아 있습니다. 확인이 필요합니다.\n%s' "$report" | json_escape)"
  exit 0
fi

printf '{"decision":"block","reason":"%s"}\n' "$(printf '자동 검사(.claude/hooks/checks.env)가 실패했습니다. 원인을 고치고 다시 확인하세요. 고칠 수 없으면 이유를 설명하세요.\n%s' "$report" | json_escape)"
exit 0
