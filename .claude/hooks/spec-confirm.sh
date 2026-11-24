#!/usr/bin/env bash
# PreToolUse 훅 (Write|Edit|MultiEdit, ROADMAP H3): spec의 판단 확정은 사람이 한다.
# SPEC.md를 고치는 변경이 시나리오 표시를 [제안]·[미정]에서 [확정]으로 바꾸면 확인 창(ask)을 띄운다.
# 한 번의 변경에 든 확정은 창 하나에 목록으로 보여준다. 사람이 허용을 누르는 것이 곧 판단의 기록이다.
#
# 한계: 새로 추가하는 시나리오를 처음부터 [확정]으로 쓰는 것은 막지 않는다(사람이 말한 내용을 받아 적는 정상 경로와
# 구분할 수 없음). 그 경우는 /review가 확인한다. MultiEdit는 편집 내용을 하나씩 대조하지 않고,
# [확정]이 들어 있으면 확인 창을 띄운다.

# shellcheck disable=SC2034  # $input은 lib.sh의 json_field가 읽는다
IFS= read -r -d '' input || true
lib="${BASH_SOURCE[0]%/*}"; [[ $lib == "${BASH_SOURCE[0]}" ]] && lib=.
# shellcheck source=lib.sh
. "$lib/lib.sh" 2>/dev/null || exit 0

root="${CLAUDE_PROJECT_DIR:-.}"
SPEC_FILE=''
# shellcheck disable=SC1091
[[ -f $root/.claude/hooks/checks.env ]] && . "$root/.claude/hooks/checks.env"
spec="${SPEC_FILE:-docs/SPEC.md}"

file="$(json_field file_path)" || exit 0
file="$(to_posix_path "$file")"
[[ $file == "$spec" || $file == */"$spec" ]] || exit 0

ask() {
  log_event spec-confirm ask "$2"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# 시나리오 줄에서 ID와 표시를 뽑는다: "F-03.2 제안" 형태로 한 줄씩
marks() {
  local line re='\*\*(F-[0-9]+\.[0-9]+)\*\*.*\[(확정|제안|미정)\]'
  while IFS= read -r line; do
    [[ $line =~ $re ]] && printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  done <<< "$1"
}

if [[ $input == *'"edits"'* ]]; then
  # MultiEdit: 새 내용에 [확정]이 있으면 확인한다
  [[ $input == *'[확정]'* ]] && ask "[사람 확인] spec 수정에 [확정] 표시가 들어 있습니다. 사람이 정한 판단이 맞는지 확인하세요 (docs/SPEC.md)." multiedit
  exit 0
fi

# 판정은 수정 조각이 아니라 "파일 전체의 수정 전과 후"로 한다. 조각만 보면 ID 없이 "[제안]"만 바꾸는 수정을 놓친다.
before='' after=''
[[ -f $file ]] && before="$(<"$file")"
if new="$(json_field new_string)"; then
  [[ $new == *'[확정]'* ]] || exit 0
  old="$(json_field old_string)" || exit 0
  [[ -n $old ]] || exit 0
  if json_bool replace_all; then after=${before//"$old"/"$new"}; else after=${before/"$old"/"$new"}; fi
elif after="$(json_field content)"; then
  [[ $after == *'[확정]'* ]] || exit 0
else
  exit 0
fi

declare -A was
while read -r id m; do [[ -n $id ]] && was[$id]=$m; done < <(marks "$before")
list=''
while read -r id m; do
  [[ $m == 확정 && ( ${was[$id]:-} == 제안 || ${was[$id]:-} == 미정 ) ]] && list+="${list:+, }$id(${was[$id]}→확정)"
done < <(marks "$after")
[[ -n $list ]] || exit 0

ask "[사람 확인] spec 판단을 확정합니다: $list. 사람이 정한 것이 맞으면 허용하고, 아니면 거부한 뒤 사람에게 물어보게 하세요 (docs/SPEC.md 표시 규칙)." transition
