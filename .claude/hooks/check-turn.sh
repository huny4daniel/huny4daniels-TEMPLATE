#!/usr/bin/env bash
# Stop 훅: Claude가 응답을 마치려 할 때, 코드가 바뀌었으면 린트(바뀐 파일)·타입 체크·단위 테스트를 돌린다.
# SPEC_TEST_GLOB가 있으면 spec 커버리지(spec-coverage.sh)도 검사한다 — spec만 바뀐 경우엔 이것만.
# 실패하면 응답 종료를 막고(decision: block) 실패 내용을 Claude에게 돌려 고치게 한다.
#
# - 바뀐 코드 파일이 없거나, 같은 상태로 이미 통과했으면 건너뛴다 (.claude/hooks/.last-pass).
# - 같은 실패 상태는 한 번만 막는다. 이미 보고한 실패가 그대로면 경고만 띄운다 (.claude/hooks/.last-fail).
#   → 실패 중인 테스트를 두고 사람에게 질문·승인을 기다리는 경우에도 매 응답 막히지 않는다.
# - 훅 때문에 이어진 응답(stop_hook_active)에서 또 실패하면 막지 않고 경고만 띄운다 (무한 반복 방지).
# 설정: .claude/hooks/checks.env

# shellcheck disable=SC2034  # $input은 lib.sh의 json_bool이 읽는다
IFS= read -r -d '' input || true
lib="${BASH_SOURCE[0]%/*}"; [[ $lib == "${BASH_SOURCE[0]}" ]] && lib=.
# shellcheck source=lib.sh
. "$lib/lib.sh" 2>/dev/null || exit 0
root="${CLAUDE_PROJECT_DIR:-.}"
conf="$root/.claude/hooks/checks.env"
[ -f "$conf" ] || exit 0
# shellcheck disable=SC1090
. "$conf"
[ -n "$LINT_CMD$TYPECHECK_CMD$TEST_CMD$SPEC_TEST_GLOB" ] || exit 0
cd "$root" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 바뀐 파일 (수정·추가·미추적, 삭제 제외). 이름 변경은 새 이름만.
all_changed="$(git status --porcelain --untracked-files=all 2>/dev/null | grep -v '^ \?D' | cut -c4- \
  | sed -e 's/.* -> //' -e 's/^"//' -e 's/"$//')"
changed="$(printf '%s\n' "$all_changed" | grep -E -- "$FILE_PATTERN")"   # 코드 파일 (린트 대상)
spec_path="${SPEC_FILE:-docs/SPEC.md}"
watch="$changed"   # 이 파일들이 바뀌었을 때만 검사한다. spec이 바뀌면 커버리지 검사가 필요하다
[ -n "$SPEC_TEST_GLOB" ] && printf '%s\n' "$all_changed" | grep -qxF -- "$spec_path" && watch="$(printf '%s\n%s' "$changed" "$spec_path" | sed '/^$/d')"
[ -n "$watch" ] || exit 0

state="$( { git diff HEAD -- . ':!.claude/hooks/.last-pass' ':!.claude/hooks/.last-fail' 2>/dev/null; printf '%s\n' "$watch" | while IFS= read -r f; do [ -f "$f" ] && cat "$f"; done; } | cksum)"
pass_file="$root/.claude/hooks/.last-pass"
fail_file="$root/.claude/hooks/.last-fail"
[ -f "$pass_file" ] && [ "$(cat "$pass_file")" = "$state" ] && { rm -f "$fail_file"; exit 0; }

json_escape() {
  sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r//g' \
    | awk 'BEGIN{ORS="\\n"} {print}'
}

report=""
add_failure() {
  report="${report}[$1 실패] $2
$(printf '%s\n' "$3" | tail -n 30)
"
}

# 셸로 해석해 실행 (따옴표·&& 사용 가능)
if [ -n "$LINT_CMD" ]; then
  files=()
  while IFS= read -r f; do [ -f "$f" ] && files+=("$f"); done <<< "$changed"
  if [ ${#files[@]} -gt 0 ]; then
    out="$(bash -c "$LINT_CMD \"\$@\"" _ "${files[@]}" 2>&1)" || add_failure "린트" "$LINT_CMD" "$out"
  fi
fi
# 타입 체크·테스트는 코드가 바뀌었을 때만 (spec만 바뀌었으면 커버리지 검사만)
if [ -n "$TYPECHECK_CMD" ] && [ -n "$changed" ]; then
  out="$(bash -c "$TYPECHECK_CMD" 2>&1)" || add_failure "타입 체크" "$TYPECHECK_CMD" "$out"
fi
if [ -n "$TEST_CMD" ] && [ -n "$changed" ]; then
  out="$(bash -c "$TEST_CMD" 2>&1)" || add_failure "테스트" "$TEST_CMD" "$out"
fi
# spec 커버리지 (ROADMAP G5): Done 기능의 시나리오마다 테스트가 있는가, 사람 확인 전 판단이 남아 있지 않은가
if [ -n "$SPEC_TEST_GLOB" ] && [ -f "$lib/spec-coverage.sh" ]; then
  out="$(bash "$lib/spec-coverage.sh" 2>&1)" || add_failure "spec 커버리지" "$spec_path" "$out"
fi

if [ -z "$report" ]; then
  printf '%s' "$state" > "$pass_file"
  rm -f "$fail_file"
  exit 0
fi

warn() {
  printf '{"systemMessage":"%s"}\n' "$(printf '자동 검사 실패가 남아 있습니다 (.claude/hooks/checks.env).\n%s' "$report" | json_escape)"
  exit 0
}

# 이미 보고한 같은 실패 상태, 또는 훅으로 이어진 응답 → 막지 않고 경고만
[ -f "$fail_file" ] && [ "$(cat "$fail_file")" = "$state" ] && warn
json_bool stop_hook_active && { printf '%s' "$state" > "$fail_file"; warn; }

printf '%s' "$state" > "$fail_file"
printf '{"decision":"block","reason":"%s"}\n' "$(printf '자동 검사(.claude/hooks/checks.env)가 실패했습니다. 원인을 고치고 다시 확인하세요. 의도한 실패(예: 사람 승인을 기다리는 중)거나 고칠 수 없으면 그 이유를 설명하고 [질문]으로 끝내세요 — 같은 실패로 다시 막지 않습니다.\n%s' "$report" | json_escape)"
exit 0
