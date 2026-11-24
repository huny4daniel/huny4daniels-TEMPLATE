#!/usr/bin/env bash
# PostToolUse 훅 (Write|Edit|MultiEdit): 수정된 파일에 포매터·린터를 바로 실행한다.
# 린트 오류가 남으면 exit 2 + stderr로 Claude에게 되돌려 즉시 고치게 한다.
# 설정: .claude/hooks/checks.env (비어 있으면 아무것도 하지 않음)

input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-.}"
conf="$root/.claude/hooks/checks.env"
[ -f "$conf" ] || exit 0
# shellcheck disable=SC1090
. "$conf"
[ -n "$FORMAT_CMD$LINT_CMD" ] || exit 0

# tool_input.file_path 추출 (jq 없이). Windows 경로의 \\ 는 / 로 바꾼다.
file="$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
  | sed -e 's/^"file_path"[[:space:]]*:[[:space:]]*"//' -e 's/"$//' -e 's#\\\\#/#g')"
[ -n "$file" ] && [ -f "$file" ] || exit 0
printf '%s' "$file" | grep -Eq -- "$FILE_PATTERN" || exit 0

cd "$root" || exit 0

if [ -n "$FORMAT_CMD" ]; then
  $FORMAT_CMD "$file" >/dev/null 2>&1
fi

if [ -n "$LINT_CMD" ]; then
  out="$($LINT_CMD "$file" 2>&1)"
  if [ $? -ne 0 ]; then
    {
      echo "[자동 린트 실패] $file"
      printf '%s\n' "$out" | tail -n 40
      echo "위 오류를 고치세요. (설정: .claude/hooks/checks.env)"
    } >&2
    exit 2
  fi
fi

exit 0
