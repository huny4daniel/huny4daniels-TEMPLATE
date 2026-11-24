#!/usr/bin/env bash
# 훅 공용 함수. 각 훅이 `. lib.sh`로 불러온다 (jq 등 외부 도구 없이, 프로세스 생성 없이).
# 호출하는 쪽에서 훅 입력 JSON을 $input에 담아 둔다.
# shellcheck disable=SC2154  # $input은 불러오는 훅이 채운다

# json_field <키>: $input에서 첫 번째 "<키>": "<문자열>" 값을 디코딩해 출력. 없으면 1을 돌려준다.
#   처리하는 이스케이프: \\ \" \/ \n \t \r  (\uXXXX는 처리하지 않음 — Claude Code는 UTF-8을 그대로 보낸다)
#   이스케이프된 따옴표(\") 안의 가짜 키는 매칭되지 않는다.
json_field() {
  local re="\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\""
  [[ $input =~ $re ]] || return 1
  local v="${BASH_REMATCH[1]}"
  v="${v//\\\\/$'\x01'}"
  v="${v//\\\"/\"}"
  v="${v//\\\//\/}"
  v="${v//\\n/$'\n'}"
  v="${v//\\t/$'\t'}"
  v="${v//\\r/$'\r'}"
  v="${v//$'\x01'/\\}"
  printf '%s' "$v"
}

# json_bool <키>: $input에서 "<키>": true 이면 0, 아니면 1
json_bool() {
  local re="\"$1\"[[:space:]]*:[[:space:]]*true"
  [[ $input =~ $re ]]
}

# to_posix_path <경로>: Windows 경로(C:\a\b)를 bash에서 쓸 수 있는 형태로 (Git Bash면 cygpath)
to_posix_path() {
  local p="${1//\\//}"
  if [[ $p =~ ^[A-Za-z]:/ ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

# log_event <훅> <결과> [분류] [소요ms]: 훅 판정을 .claude/metrics/events.jsonl에 한 줄 남긴다 (ROADMAP C1).
#   명령 원문·파일 내용은 남기지 않는다(비밀 값이 섞일 수 있음) — 분류 이름만.
#   기록 실패는 조용히 넘어간다(판정에 영향 없음). 날짜·세션 ID는 bash 내장으로 얻어 프로세스를 만들지 않는다.
#   HOOK_EVENT_LOG=0이면 기록하지 않는다.
log_event() {
  [[ ${HOOK_EVENT_LOG:-1} == 0 ]] && return 0
  local dir="${CLAUDE_PROJECT_DIR:-.}/.claude/metrics" ts sid='' c=${3:-} re='"session_id"[[:space:]]*:[[:space:]]*"([^"\]*)"'
  [[ -d $dir ]] || mkdir -p "$dir" 2>/dev/null || return 0
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  [[ $input =~ $re ]] && sid=${BASH_REMATCH[1]}
  c=${c//\"/}; c=${c//\/}
  {
    printf '{"ts":"%s","session":"%s","hook":"%s","result":"%s"' "$ts" "$sid" "$1" "$2"
    [[ -n $c ]] && printf ',"cat":"%s"' "$c"
    [[ -n ${4:-} ]] && printf ',"ms":%s' "$4"
    printf '}\n'
  } >> "$dir/events.jsonl" 2>/dev/null || true
}
