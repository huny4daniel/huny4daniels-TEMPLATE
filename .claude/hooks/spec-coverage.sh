#!/usr/bin/env bash
# spec 커버리지 검사와 상태 요약 (ROADMAP G5). jq·python 없이 bash만 쓴다.
#
#   spec-coverage.sh            검사: Done 기능의 자동 시나리오마다 테스트에 ID가 있는가,
#                               Done 기능에 사람 확인 전 판단([제안]·[미정])이나 [탐색]이 남아 있지 않은가.
#                               문제가 있으면 목록을 출력하고 1로 끝난다. SPEC_TEST_GLOB가 비어 있으면 검사하지 않는다(0).
#   spec-coverage.sh --summary  요약: 기능별 우선순위·상태·[미정]·[제안] 수와 커버리지, 다음 후보. 항상 0.
#
# 설정 (.claude/hooks/checks.env):
#   SPEC_FILE       spec 경로 (기본 docs/SPEC.md)
#   SPEC_TEST_GLOB  테스트 파일 glob, 공백으로 구분 (예: 'tests/**/*.py apps/**/src/**/*.test.ts')
#
# 테스트에서 시나리오 ID를 찾는 형식: F-03.1 또는 f03_1 / F03_1 (대소문자 무시, 뒤에 숫자가 이어지지 않을 것).
# 한계: ID가 테스트 파일에 있는지만 본다. 그 테스트가 시나리오를 제대로 검증하는지는 /review·5단계 대조(G4)가 본다.

mode=check
[[ ${1:-} == --summary ]] && mode=summary

root="${CLAUDE_PROJECT_DIR:-.}"
cd "$root" 2>/dev/null || exit 0
SPEC_FILE='' SPEC_TEST_GLOB=''
# shellcheck disable=SC1091
[[ -f .claude/hooks/checks.env ]] && . .claude/hooks/checks.env
spec="${SPEC_FILE:-docs/SPEC.md}"
if [[ ! -f $spec ]]; then
  [[ $mode == summary ]] && echo "[spec 요약] $spec 없음"
  exit 0
fi
[[ $mode == check && -z $SPEC_TEST_GLOB ]] && exit 0

# ---------- SPEC.md 읽기 ----------
# 기능 제목 줄: ### F-03 이름 — Must · Done [탐색]
re_feat='^###[[:space:]]+(F-[0-9]+)[[:space:]]+(.*[^[:space:]])[[:space:]]+—[[:space:]]+(Must|Should|Could)[[:space:]]+·[[:space:]]+(Planned|In Progress|Done|Dropped)([[:space:]]+\[탐색\])?[[:space:]]*$'
# 시나리오 줄: - **F-03.1** 이름 [확정]
re_scen='^[[:space:]]*[-*][[:space:]]+\*\*(F-[0-9]+\.[0-9]+)\*\*(.*)$'

feats=() scen_ids=()
declare -A f_name f_pri f_state f_explore f_scen f_undecided f_proposed s_name s_manual s_mark
cur='' in_comment=0
while IFS= read -r line || [[ -n $line ]]; do
  line=${line%$'\r'}
  # HTML 주석(작성 예시) 안은 건너뛴다
  if (( in_comment )); then [[ $line == *'-->'* ]] && in_comment=0; continue; fi
  if [[ $line == *'<!--'* ]]; then [[ $line == *'-->'* ]] || in_comment=1; continue; fi
  if [[ $line =~ $re_feat ]]; then
    cur=${BASH_REMATCH[1]}
    feats+=("$cur")
    f_name[$cur]=${BASH_REMATCH[2]}; f_pri[$cur]=${BASH_REMATCH[3]}; f_state[$cur]=${BASH_REMATCH[4]}
    [[ -n ${BASH_REMATCH[5]} ]] && f_explore[$cur]=1 || f_explore[$cur]=0
    f_scen[$cur]=''; f_undecided[$cur]=0; f_proposed[$cur]=0
    continue
  fi
  [[ $line == '#'* ]] && cur=''   # 기능 형식이 아닌 제목을 만나면 기능 범위가 끝난다
  if [[ -n $cur && $line =~ $re_scen ]]; then
    id=${BASH_REMATCH[1]} rest=${BASH_REMATCH[2]}
    scen_ids+=("$id")
    f_scen[$cur]+="$id "
    name=${rest%%[*}; name=${name%%(수동)*}; name=${name#"${name%%[![:space:]]*}"}; name=${name%"${name##*[![:space:]]}"}
    s_name[$id]=$name
    s_mark[$id]=''
    [[ $rest == *'[미정]'* ]] && { s_mark[$id]='미정'; (( f_undecided[$cur]++ )); }
    [[ $rest == *'[제안]'* ]] && { s_mark[$id]='제안'; (( f_proposed[$cur]++ )); }
    [[ $rest == *'(수동)'* ]] && s_manual[$id]=1 || s_manual[$id]=0
  fi
done < "$spec"

# ---------- 테스트 파일 모으기 ----------
tests_text='' test_files=0
if [[ -n $SPEC_TEST_GLOB ]]; then
  shopt -s globstar nullglob
  declare -A seen
  # shellcheck disable=SC2086  # glob 확장이 목적
  for f in $SPEC_TEST_GLOB; do
    [[ -f $f && -z ${seen[$f]} ]] || continue
    seen[$f]=1; (( test_files++ ))
    tests_text+=$'\n'"$(<"$f")"
  done
  shopt -u globstar nullglob
fi

# has_test <F-03.1>: 테스트 본문에 F-03.1 또는 f03_1 형태가 있는가
has_test() {
  local id=$1 num=${1#F-} a b
  a=${num%%.*}; b=${num#*.}
  shopt -s nocasematch
  local re="(^|[^0-9A-Za-z])(F-${a}\.${b}|F${a}_${b})([^0-9]|$)"
  [[ $tests_text =~ $re ]]; local r=$?
  shopt -u nocasematch
  return $r
}

auto_scen() { local id=$1; [[ ${s_manual[$id]} == 0 && -z ${s_mark[$id]} ]]; }

# ---------- 요약 ----------
if [[ $mode == summary ]]; then
  scale=$(grep -m1 -E '^\| *규모 *\|' "$spec" | sed -E 's/^\| *규모 *\| *([^|]*[^| ]) *\|.*/\1/')
  echo "[spec 요약] $spec${scale:+ (규모: $scale)}"
  (( ${#feats[@]} )) || { echo "기능 없음 — 1단계에서 SPEC.md 2절을 채운다"; exit 0; }
  must=0 must_done=0 und=0 prop=0 next_ask='' next_go=''
  for f in "${feats[@]}"; do
    n=0 auto=0 cov=0 line=''
    for id in ${f_scen[$f]}; do
      (( n++ ))
      auto_scen "$id" || continue
      (( auto++ )); has_test "$id" && (( cov++ ))
    done
    line="$f ${f_name[$f]} — ${f_pri[$f]} · ${f_state[$f]}"
    (( f_explore[$f] )) && line+=" [탐색]"
    line+="  시나리오 $n"
    [[ -n $SPEC_TEST_GLOB ]] && (( auto )) && line+=" (자동 ${auto}개 중 테스트 있음 ${cov})"
    (( f_undecided[$f] )) && line+=", [미정] ${f_undecided[$f]}"
    (( f_proposed[$f] )) && line+=", [제안] ${f_proposed[$f]}"
    echo "- $line"
    (( und += f_undecided[$f], prop += f_proposed[$f] ))
    if [[ ${f_pri[$f]} == Must ]]; then
      (( must++ )); [[ ${f_state[$f]} == Done ]] && (( must_done++ ))
      if [[ ${f_state[$f]} != Done && ${f_state[$f]} != Dropped ]]; then
        if (( f_undecided[$f] + f_proposed[$f] )); then [[ -z $next_ask ]] && next_ask=$f
        else [[ -z $next_go ]] && next_go=$f; fi
      fi
    fi
  done
  echo "합계: Must ${must}개 중 Done ${must_done}개 · [미정] ${und} · [제안] ${prop}"
  if [[ -n $next_go ]]; then echo "다음 후보: $next_go ${f_name[$next_go]} (판단 남은 것 없음 — 진행 가능)"; fi
  if [[ -n $next_ask ]]; then echo "판단 필요: $next_ask ${f_name[$next_ask]} ([미정]·[제안]을 먼저 묻는다)"; fi
  exit 0
fi

# ---------- 검사 ----------
problems=() checked=0 done_n=0
for f in "${feats[@]}"; do
  [[ ${f_state[$f]} == Done ]] || continue
  (( done_n++ ))
  label="$f ${f_name[$f]}"
  (( f_explore[$f] )) && problems+=("$label: [탐색] 기능은 Done이 될 수 없다 — 탐색을 끝내고 시나리오를 쓴 뒤 [탐색]을 뗀다")
  for id in ${f_scen[$f]}; do
    case ${s_mark[$id]} in
      미정) problems+=("$id ${s_name[$id]} ($label · Done): [미정]이 남아 있다 — 사람의 판단 없이 Done이 될 수 없다"); continue ;;
      제안) problems+=("$id ${s_name[$id]} ($label · Done): [제안]이 남아 있다 — 사람이 확인해 [확정]으로 바꿔야 Done이다"); continue ;;
    esac
    (( s_manual[$id] )) && continue
    (( checked++ ))
    alt=${id,,}; alt=${alt/f-/f}; alt=${alt/./_}
    has_test "$id" || problems+=("$id ${s_name[$id]} ($label · Done): 테스트에서 ID를 찾지 못함 ($id 또는 $alt)")
  done
done

# 테스트에만 있는 ID (참고 — 실패로 치지 않는다)
orphans=()
if [[ -n $tests_text ]]; then
  declare -A known
  for id in "${scen_ids[@]}"; do known[$id]=1; done
  while IFS= read -r m; do
    [[ -z $m ]] && continue
    m=${m^^}; m=${m/_/.}; [[ $m == F-* ]] || m="F-${m#F}"
    [[ -z ${known[$m]} ]] && orphans+=("$m")
  done < <(grep -oiE '(^|[^0-9A-Za-z])(F-[0-9]+\.[0-9]+|F[0-9]+_[0-9]+)([^0-9]|$)' <<< "$tests_text" \
            | grep -oiE 'F-?[0-9]+[._][0-9]+' | sort -u)
fi

if (( ${#problems[@]} == 0 )); then
  (( ${#orphans[@]} )) && echo "[spec 커버리지] 참고: 테스트에만 있고 $spec에 없는 ID — ${orphans[*]} (오타이거나 spec에서 지워진 시나리오)"
  exit 0
fi
echo "[spec 커버리지] $spec — Done 기능 ${done_n}개, 자동 시나리오 ${checked}개 검사, 테스트 파일 ${test_files}개"
printf -- '- %s\n' "${problems[@]}"
(( ${#orphans[@]} )) && echo "참고: 테스트에만 있고 spec에 없는 ID — ${orphans[*]}"
echo "고치는 방법: 빠진 시나리오의 테스트를 쓰고 이름·주석에 ID를 단다. 아직 다 되지 않았으면 기능 상태를 In Progress로 둔다. [제안]·[미정]은 사람에게 묻는다."
exit 1
