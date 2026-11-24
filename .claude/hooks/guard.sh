#!/usr/bin/env bash
# PreToolUse 훅 (Bash|PowerShell): 되돌리기 어렵거나 외부에 영향을 주는 명령 직전에
# 사람 확인을 받는다. 막지 않고 permissionDecision "ask"로 확인 창만 띄운다.
#
#   1) main 반영·태그·릴리즈: main/master push, 태그 push, force push, 원격 삭제,
#      gh pr merge(CI 실패·진행 중이면 deny), gh release create/delete/edit
#   2) 삭제·되돌리기 불가: rm -r, Remove-Item -Recurse, git reset --hard, git clean -f,
#      git branch -D, 작업 내용 폐기(checkout/restore .), gh repo/release delete
#   3) 배포: 패키지 저장소 publish, docker push, 클라우드·서버 배포 명령
#   4) 외부 API 쓰기: curl/wget/Invoke-* 의 POST·PUT·PATCH·DELETE, gh api 쓰기 요청
#
# 판정 대상은 tool_input.command 하나뿐이다 (description·cwd 등 다른 필드는 보지 않음).
# 모든 셸 명령마다 실행되므로 bash 내장 정규식으로 판정하고(프로세스 생성 없음),
# 관련 단어가 없는 명령은 곧바로 통과시킨다. 외부 도구(jq 등)는 쓰지 않는다.

# shellcheck disable=SC2034  # $input은 lib.sh의 json_field가 읽는다
IFS= read -r -d '' input || true
lib="${BASH_SOURCE[0]%/*}"; [[ $lib == "${BASH_SOURCE[0]}" ]] && lib=.
# shellcheck source=lib.sh
. "$lib/lib.sh" 2>/dev/null || exit 0

cmd="$(json_field command)" || exit 0
[[ -n $cmd ]] || exit 0

# 판정 이유의 [분류]를 이벤트 로그에 남긴다 (명령 원문은 남기지 않음)
reason_cat() { local c=${1#\[}; printf -v REPLY '%s' "${c%%\]*}"; }

ask() {
  reason_cat "$1"; log_event guard ask "$REPLY"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

deny() {
  reason_cat "$1"; log_event guard deny "$REPLY"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# has: 대소문자 무시 / hasc: 대소문자 구분 (bash 내장 ERE, 대상은 $cmd)
has()  { shopt -s nocasematch; [[ $cmd =~ $1 ]]; local r=$?; shopt -u nocasematch; return $r; }
hasc() { [[ $cmd =~ $1 ]]; }

# ---------- 5) 비밀 파일 접근 ----------
# settings.json의 Read deny는 파일 도구에만 걸린다. 셸에서 .env·키스토어·인증서·SSH 키를 다루는 명령은
# 읽기 명령에 한정하지 않고 파일명으로 판정한다 (cp·base64·python open 같은 우회까지 잡기 위함).
# 예시 파일(.env.example 등)은 이름을 지운 뒤 판정해 "예시 + 실제 파일"이 함께 있는 경우도 놓치지 않는다.
# 대소문자를 구분한다 (process.env.HOME 같은 환경 변수 접근은 통과).
secret_scan=${cmd//.env.example/}; secret_scan=${secret_scan//.env.sample/}
secret_scan=${secret_scan//.env.template/}; secret_scan=${secret_scan//.env.dist/}
# 템플릿의 검사 설정(.claude/hooks/checks.env)은 비밀이 아니다 — 에이전트 평가(H2)에서 오탐으로 확인됨
secret_scan=${secret_scan//checks.env/}
if [[ $secret_scan =~ (\.env([^.A-Za-z0-9_]|\.[a-z]+|$)|\.(jks|keystore|pem|p12|pfx|key)([^A-Za-z0-9]|$)|id_(rsa|ed25519|ecdsa)([^A-Za-z0-9._]|$)) ]]; then
  ask "[비밀 값] 비밀 파일(${BASH_REMATCH[1]})을 셸로 읽거나 다루는 명령입니다. 값을 출력·전송·커밋하지 않는지 확인하세요."
fi

# 빠른 통과: 판정 대상 명령어가 하나도 없으면 바로 종료
has '(^|[^A-Za-z0-9_-])(git|gh|rm|rmdir|rd|del|remove-item|npm|pnpm|yarn|bun|twine|uv|poetry|cargo|gem|gradlew?|docker|kubectl|helm|terraform|firebase|netlify|fly|flyctl|wrangler|railway|vercel|gcloud|aws|curl|wget|invoke-webrequest|invoke-restmethod|iwr|irm)([^A-Za-z0-9_-]|$)' || exit 0

# ---------- git push 대상 판정 ----------
# 복합 명령(&& || ; |)을 나눠 git push마다 대상 refspec을 본다. main/master로 가면 $push_main에 사유를 담는다.
is_main_ref() {
  local r=${1,,}
  r=${r#+}; r=${r#refs/heads/}
  [[ $r == main || $r == master ]]
}

check_push() {  # $1: git push가 들어 있는 명령 조각
  local -a t
  read -ra t <<< "$1"
  local n=${#t[@]} i=0 dir="${CLAUDE_PROJECT_DIR:-.}" remote="" ref dst cur up
  local -a refs=()
  while (( i < n )) && [[ ${t[i],,} != git ]]; do (( i++ )); done
  (( i++ ))
  # git 전역 옵션: -C <dir>, -c <k=v>
  while (( i < n )); do
    case ${t[i]} in
      -C) dir=${t[i+1]}; [[ $dir == /* || $dir =~ ^[A-Za-z]: ]] || dir="${CLAUDE_PROJECT_DIR:-.}/$dir"; (( i += 2 )) ;;
      -c) (( i += 2 )) ;;
      *) [[ ${t[i],,} == push ]] && { (( i++ )); break; }; (( i++ )) ;;
    esac
  done
  # push 옵션과 인자
  while (( i < n )); do
    case ${t[i],,} in
      --all|--mirror|--branches) push_main="push 대상에 모든 브랜치(main 포함)가 들어갑니다 (${t[i]})"; return ;;
      -o|--push-option|--repo|--receive-pack|--exec) (( i += 2 )); continue ;;
      -*) ;;
      *) if [[ -z $remote ]]; then remote=${t[i]}; else refs+=("${t[i]}"); fi ;;
    esac
    (( i++ ))
  done
  cur=$(git -C "$dir" branch --show-current 2>/dev/null)
  if (( ${#refs[@]} == 0 )); then
    if is_main_ref "$cur"; then push_main="현재 브랜치가 $cur 입니다. main에 직접 push하게 됩니다"; return; fi
    up=$(git -C "$dir" rev-parse --abbrev-ref '@{u}' 2>/dev/null)
    if [[ -n $up ]] && is_main_ref "${up#*/}"; then push_main="현재 브랜치($cur)의 upstream이 $up 입니다. main에 push하게 됩니다"; return; fi
    return
  fi
  for ref in "${refs[@]}"; do
    if [[ $ref == *:* ]]; then dst=${ref#*:}; else dst=$ref; fi
    [[ ${dst,,} == head ]] && dst=$cur
    if is_main_ref "$dst"; then push_main="main 브랜치 push입니다 ($ref)"; return; fi
  done
}

push_main=""
if has 'git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+push'; then
  segs=${cmd//&&/$'\n'}; segs=${segs//||/$'\n'}; segs=${segs//;/$'\n'}; segs=${segs//|/$'\n'}
  while IFS= read -r seg; do
    shopt -s nocasematch
    if [[ $seg =~ (^|[[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$) ]]; then
      shopt -u nocasematch; check_push "$seg"
      [[ -n $push_main ]] && break
    fi
    shopt -u nocasematch
  done <<< "$segs"
fi

# ---------- 1) main 반영·태그·릴리즈 ----------
# PR 병합: 먼저 CI 상태를 조회한다. 실패·진행 중이면 거부, 통과면 사람 확인.
# (GitHub 보호 규칙의 "CI 통과 필수"를 비공개 저장소에서도 대신하기 위함)
if has 'gh[[:space:]]+pr[[:space:]]+merge'; then
  # 'gh pr merge <번호|브랜치|URL>'의 대상. 없으면 현재 브랜치의 PR.
  target=""
  [[ $cmd =~ gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+([^-[:space:]][^[:space:]]*) ]] && target=${BASH_REMATCH[1]}
  # shellcheck disable=SC2086  # target이 비어 있으면 인자를 넘기지 않기 위해 따옴표 없이 쓴다
  checks="$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && gh pr checks $target 2>&1)"
  rc=$?
  summary="${checks//[\"\\]/}"; summary="${summary//[$'\t\r\n']/ }"; summary="${summary:0:300}"
  case $rc in
    0) ask "[main 반영] PR 병합입니다. CI 통과 확인됨. 병합 승인 여부를 확인하세요. (.claude/process/git-flow.md)" ;;
    8) deny "[CI 진행 중] 아직 CI가 끝나지 않아 병합할 수 없습니다. 'gh pr checks --watch'로 완료를 기다린 뒤 다시 시도하세요. ($summary)" ;;
  esac
  shopt -s nocasematch
  if [[ $checks == *"no checks reported"* ]]; then
    ask "[main 반영] PR 병합입니다. 이 PR에는 CI 결과가 없습니다 (CI 미설정 또는 미실행). 그래도 병합할지 확인하세요."
  fi
  if [[ $checks =~ (fail|cancel|error)[[:space:]] ]] && ! [[ $checks =~ (could\ not|not\ found|no\ pull\ requests|authentication|gh\ auth\ login|network) ]]; then
    deny "[CI 실패] CI가 통과하지 않아 병합할 수 없습니다. 실패한 검사를 고친 뒤 다시 시도하세요. ($summary)"
  fi
  shopt -u nocasematch
  ask "[main 반영] PR 병합입니다. CI 상태를 확인하지 못했습니다 ($summary). CI 통과 여부를 직접 확인하세요."
fi
if has 'gh[[:space:]]+release[[:space:]]+(create|delete|edit|upload)'; then
  ask "[릴리즈] GitHub 릴리즈 생성·수정·삭제입니다. (.claude/process/06-release.md)"
fi
if has 'git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+push'; then
  if has '(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
    ask "[main 반영] force push입니다. 원격 이력을 덮어씁니다."
  fi
  if has '(--delete|[[:space:]]-d[[:space:]]|[[:space:]]:[A-Za-z0-9])'; then
    ask "[삭제] 원격 브랜치·태그 삭제입니다."
  fi
  if has '(--tags|--follow-tags|refs/tags/|[[:space:]]v[0-9]+\.[0-9]+)'; then
    ask "[릴리즈] 버전 태그 push입니다. 릴리즈 워크플로가 실행될 수 있습니다. (.claude/process/06-release.md)"
  fi
  if [[ -n $push_main ]]; then
    ask "[main 반영] $push_main. 직접 반영이 허용된 변경(문서만 수정 등)인지 확인하세요. (.claude/process/git-flow.md)"
  fi
fi

# ---------- 2) 삭제·되돌리기 불가 ----------
if has '(^|[^A-Za-z0-9_-])rm[[:space:]]+(-[A-Za-z]*[rR][A-Za-z]*|--recursive)'; then
  ask "[삭제] 재귀 삭제(rm -r)입니다. 대상 경로를 확인하세요."
fi
if has 'Remove-Item[^|;&]*-(Recurse|r)([[:space:]]|$)' || has '(rmdir|rd)[[:space:]]+/s' || has 'del[[:space:]]+/[sq]'; then
  ask "[삭제] 재귀 삭제입니다. 대상 경로를 확인하세요."
fi
if has 'git[[:space:]]+reset[[:space:]]+[^|;&]*--hard' || has 'git[[:space:]]+clean[[:space:]]+-[A-Za-z]*f'; then
  ask "[삭제] 커밋되지 않은 작업을 지우는 명령입니다 (reset --hard / clean -f)."
fi
if hasc 'git[[:space:]]+branch[[:space:]]+[^|;&]*-D' || has 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' || has 'git[[:space:]]+stash[[:space:]]+(drop|clear)'; then
  ask "[삭제] 브랜치 강제 삭제 또는 작업 내용 폐기입니다."
fi
if has 'gh[[:space:]]+(repo|issue|label|secret|variable)[[:space:]]+delete' || has 'gh[[:space:]]+repo[[:space:]]+(archive|edit[^|;&]*--visibility)'; then
  ask "[삭제·공개] 저장소·이슈·비밀 값 삭제 또는 저장소 보관·공개 범위 변경입니다."
fi

# ---------- 3) 배포 ----------
if has '(npm|pnpm|yarn|bun)[[:space:]]+publish' || has '(twine[[:space:]]+upload|uv[[:space:]]+publish|poetry[[:space:]]+publish|cargo[[:space:]]+publish|gem[[:space:]]+push)' || has 'gradlew?(\.bat)?[[:space:]]+[^|;&]*publish'; then
  ask "[배포] 패키지 저장소 배포(publish)입니다."
fi
if has 'docker[[:space:]]+(push|compose[[:space:]]+push)' || has '(kubectl|helm)[[:space:]]+(apply|delete|install|upgrade|uninstall)' || has 'terraform[[:space:]]+(apply|destroy)'; then
  ask "[배포] 컨테이너·인프라 배포 또는 변경입니다."
fi
if has '(firebase|netlify|fly|flyctl|wrangler|railway)[[:space:]]+deploy' || has 'vercel[^|;&]*--prod' || has 'gcloud[^|;&]*deploy' || has 'aws[[:space:]]+[^|;&]*(deploy|s3[[:space:]]+(cp|sync|rm))'; then
  ask "[배포] 클라우드·서버 배포입니다."
fi

# ---------- 4) 외부 API 쓰기 ----------
if has '(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm)([[:space:]]|\.exe)'; then
  if has '(-X|--request|-Method)[[:space:]]*"?(POST|PUT|PATCH|DELETE)' || has '[[:space:]](-d|--data|--data-[a-z]+|-F|--form|--post-data|--post-file|-T|--upload-file|-Body)([[:space:]=]|$)'; then
    ask "[외부 API] 외부 서비스에 데이터를 보내거나 변경하는 요청입니다. 대상과 내용을 확인하세요."
  fi
fi
if has 'gh[[:space:]]+api'; then
  # 마일스톤 생성·수정은 되돌릴 수 있는 계획 작업이라 통과 (삭제는 확인)
  if has 'repos/[^[:space:]]+/milestones' && ! has '(-X|--method)[[:space:]]*"?DELETE'; then
    exit 0
  fi
  if has '(-X|--method)[[:space:]]*"?(POST|PUT|PATCH|DELETE)' || has '[[:space:]](-f|-F|--field|--raw-field|--input)[[:space:]]'; then
    ask "[외부 API] GitHub API 쓰기 요청입니다. (저장소 설정·보호 규칙 변경 등)"
  fi
fi

exit 0
