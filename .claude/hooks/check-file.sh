#!/usr/bin/env bash
# PostToolUse 훅 (Write|Edit|MultiEdit): 수정된 파일에 포매터·린터를 바로 실행한다.
# 린트 오류가 남으면 exit 2 + stderr로 Claude에게 되돌려 즉시 고치게 한다.
# 설정: .claude/hooks/checks.env (비어 있으면 아무것도 하지 않음)

# shellcheck disable=SC2034  # $input은 lib.sh의 json_field가 읽는다
IFS= read -r -d '' input || true
lib="${BASH_SOURCE[0]%/*}"; [[ $lib == "${BASH_SOURCE[0]}" ]] && lib=.
# shellcheck source=lib.sh
. "$lib/lib.sh" 2>/dev/null || exit 0
root="${CLAUDE_PROJECT_DIR:-.}"
conf="$root/.claude/hooks/checks.env"
[ -f "$conf" ] || exit 0
# shellcheck disable=SC1090
. "$conf"
[ -n "$FORMAT_CMD$LINT_CMD" ] || exit 0

# tool_input.file_path 추출 (lib.sh: JSON 이스케이프 디코딩 → Windows 경로는 bash 경로로 변환)
file="$(json_field file_path)" || exit 0
file="$(to_posix_path "$file")"
[[ -n $file && -f $file ]] || exit 0
[[ $file =~ $FILE_PATTERN ]] || exit 0

cd "$root" || exit 0

# 명령 문자열은 셸로 해석해 실행한다 (따옴표·&& 사용 가능). 파일 경로는 마지막 인자로 붙는다.
run_on_file() { bash -c "$1 \"\$1\"" _ "$2"; }

if [ -n "$FORMAT_CMD" ]; then
  run_on_file "$FORMAT_CMD" "$file" >/dev/null 2>&1
fi

if [ -n "$LINT_CMD" ]; then
  out="$(run_on_file "$LINT_CMD" "$file" 2>&1)"
  if [ $? -ne 0 ]; then
    {
      echo "[자동 린트 실패] $file"
      printf '%s\n' "$out" | tail -n 40
      echo "위 오류를 고치세요. (설정: .claude/hooks/checks.env)"
    } >&2
    log_event check-file lint-fail
    exit 2
  fi
fi

exit 0
