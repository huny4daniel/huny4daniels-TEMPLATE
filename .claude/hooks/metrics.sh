#!/usr/bin/env bash
# 훅 이벤트 요약 (ROADMAP C1). .claude/metrics/events.jsonl을 읽어 한 화면으로 센다.
#
#   metrics.sh            오늘
#   metrics.sh 2026-11    그 접두어로 시작하는 날짜 (월·연도 단위)
#   metrics.sh all        전체
#
# /wrap이 세션 로그에 한 줄 요약을 붙일 때 쓴다. 원본 로그는 로컬에만 둔다(git 제외).

root="${CLAUDE_PROJECT_DIR:-.}"
log="$root/.claude/metrics/events.jsonl"
[[ -f $log ]] || { echo "[훅 이벤트] 기록 없음"; exit 0; }

if [[ ${1:-} == all ]]; then prefix=''; label='전체'
elif [[ -n ${1:-} ]]; then prefix=$1; label=$1
else printf -v prefix '%(%Y-%m-%d)T' -1; label="$prefix (오늘)"; fi

awk -v prefix="$prefix" -v label="$label" '
function field(name,   re, s) {
  re = "\"" name "\":\"[^\"]*\""
  if (match($0, re)) { s = substr($0, RSTART, RLENGTH); sub("^\"" name "\":\"", "", s); sub("\"$", "", s); return s }
  return ""
}
function num(name,   re, s) {
  re = "\"" name "\":[0-9]+"
  if (match($0, re)) { s = substr($0, RSTART, RLENGTH); sub("^\"" name "\":", "", s); return s + 0 }
  return -1
}
{
  ts = field("ts"); if (prefix != "" && index(ts, prefix) != 1) next
  hook = field("hook"); res = field("result"); cat = field("cat"); ses = field("session"); ms = num("ms")
  if (hook == "guard") {
    g[res]++; if (cat != "") { gc[res, cat]++; gcats[cat] = 1 }
  } else if (hook == "check-turn") {
    t[res]++
    if (res == "block") { n = split(cat, parts, ","); for (i = 1; i <= n; i++) tc[parts[i]]++; pending[ses]++ ; blocked_total++ }
    if (res == "pass" && pending[ses] > 0) { fixed += pending[ses]; pending[ses] = 0 }
    if (ms >= 0) times[++nt] = ms
  } else if (hook == "check-file") {
    f[res]++
  } else if (hook == "spec-confirm") {
    sc++
  }
}
END {
  printf "[훅 이벤트] %s\n", label
  s = ""; for (c in gcats) if (gc["ask", c]) s = s (s ? ", " : "") c " " gc["ask", c]
  printf "- 확인 창 %d%s · 거부 %d\n", g["ask"], (s ? " (" s ")" : ""), g["deny"]
  s = ""; for (c in tc) s = s (s ? ", " : "") c " " tc[c]
  printf "- 응답 종료 검사: 통과 %d · 차단 %d%s · 경고 %d", t["pass"], t["block"], (s ? " (" s ")" : ""), t["warn"]
  if (blocked_total) printf " · 차단 뒤 같은 세션에서 통과 %d/%d", fixed, blocked_total
  printf "\n- 파일 수정 직후 린트 실패 %d\n", f["lint-fail"]
  printf "- spec 판단 확정 확인 창 %d\n", sc
  if (nt) {
    # 삽입 정렬 (건수가 적다)
    for (i = 2; i <= nt; i++) { v = times[i]; j = i - 1; while (j >= 1 && times[j] > v) { times[j + 1] = times[j]; j-- } times[j + 1] = v }
    printf "- 응답 종료 검사 시간: 중앙값 %dms · 최대 %dms (%d회)\n", times[int((nt + 1) / 2)], times[nt], nt
  }
}' "$log"
