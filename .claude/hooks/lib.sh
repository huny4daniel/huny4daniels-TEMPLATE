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
