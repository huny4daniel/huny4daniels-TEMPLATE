#!/usr/bin/env bash
# 에이전트 행동 평가 실행기 (ROADMAP H2, 템플릿 전용).
#   bash .github/agent-evals/run.sh [케이스 이름...]   (없으면 전부)
# 케이스마다: 템플릿(HEAD)을 임시 폴더에 풀고 템플릿 전용 경로를 지운 뒤 fixture를 덮어써 "진행 중인 프로젝트"를 만든다.
# 그 폴더에서 headless Claude(claude -p)를 프롬프트 하나로 돌리고, 결과를 케이스의 grade.sh가 결정론적으로 채점한다.
# 구독 로그인으로 돌리면 구독 사용량에서 차감된다. CI에서는 돌리지 않는다(비용·로그인 정보).
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out_root="${EVAL_OUT:-$repo/.github/agent-evals/results}"
timeout_s="${EVAL_TIMEOUT:-600}"
mkdir -p "$out_root"
# Windows: 실행기에서 띄운 Claude가 Git Bash를 찾지 못하면 훅이 모두 실패한다 (guardrails.md "Windows 주의") — 경로를 넘겨준다
if [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]] && [[ -z ${CLAUDE_CODE_GIT_BASH_PATH:-} ]]; then
  gb="$(cygpath -w /)bin\bash.exe"; [[ -f $(cygpath -u "$gb") ]] && export CLAUDE_CODE_GIT_BASH_PATH="$gb"
fi
cases=("$@"); (( ${#cases[@]} )) || cases=($(ls "$here/cases"))
stamp=$(date +%Y%m%d-%H%M%S)
summary="$out_root/$stamp.md"
echo "| 케이스 | 결과 | 근거 |" > "$summary"; echo "|---|---|---|" >> "$summary"

for c in "${cases[@]}"; do
  cdir="$here/cases/$c"; [[ -d $cdir ]] || { echo "케이스 없음: $c"; continue; }
  work=$(mktemp -d)
  # 템플릿 전용 경로는 풀 때부터 뺀다 (git archive의 제외 경로 지정)
  excl=(); while IFS= read -r p; do [[ -z $p || $p == \#* ]] && continue; excl+=(":(exclude)${p%/}"); done < "$repo/.template-only"
  git -C "$repo" archive HEAD -- . "${excl[@]}" | tar -x -C "$work"
  cp -r "$cdir/fixture/." "$work/"
  ( cd "$work" && git init -q -b main && git add -A && git -c user.email=eval@local -c user.name=eval commit -qm "평가 시작 상태" )
  echo "== $c ($work)"
  ( cd "$work" && timeout "$timeout_s" claude -p "$(cat "$cdir/prompt.txt")" \
      --output-format json --permission-mode acceptEdits --no-session-persistence \
      --allowedTools "Bash(python -m unittest*)" "Bash(bash .claude/hooks/spec-coverage.sh*)" "Bash(git status*)" "Bash(git diff*)" "Bash(git log*)" \
      > "$work/.eval-result.json" 2> "$work/.eval-stderr.txt" ) || echo "(claude 종료 코드 $?)"
  verdict=$(bash "$cdir/grade.sh" "$work" 2>&1); rc=$?
  result=$([[ $rc == 0 ]] && echo PASS || echo FAIL)
  echo "$result — $verdict"
  printf '| %s | %s | %s |\n' "$c" "$result" "$(tr '\n' ' ' <<< "$verdict")" >> "$summary"
  mkdir -p "$out_root/$stamp-$c" && cp "$work/.eval-result.json" "$work/.eval-stderr.txt" "$out_root/$stamp-$c/" 2>/dev/null
  ( cd "$work" && git status --porcelain > "$out_root/$stamp-$c/git-status.txt"; git diff > "$out_root/$stamp-$c/git-diff.txt"; cp docs/SPEC.md "$out_root/$stamp-$c/SPEC.after.md"; cp .claude/metrics/events.jsonl "$out_root/$stamp-$c/" 2>/dev/null )
done
echo; cat "$summary"
