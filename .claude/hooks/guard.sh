#!/usr/bin/env bash
# PreToolUse 훅 (Bash|PowerShell): 되돌리기 어렵거나 외부에 영향을 주는 명령 직전에
# 사람 확인을 받는다. 막지 않고 permissionDecision "ask"로 확인 창만 띄운다.
#
#   1) main 반영·태그·릴리즈: main/master push, 태그 push, force push, 원격 삭제,
#      gh pr merge, gh release create/delete/edit
#   2) 삭제·되돌리기 불가: rm -r, Remove-Item -Recurse, git reset --hard, git clean -f,
#      git branch -D, 작업 내용 폐기(checkout/restore .), gh repo/release delete
#   3) 배포: 패키지 저장소 publish, docker push, 클라우드·서버 배포 명령
#   4) 외부 API 쓰기: curl/wget/Invoke-* 의 POST·PUT·PATCH·DELETE, gh api 쓰기 요청
#
# 외부 도구(jq 등) 없이 bash + grep만 사용한다. 조회·작업 브랜치 push·PR 생성은 통과한다.

input="$(cat)"

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

has() { printf '%s' "$input" | grep -Eiq -- "$1"; }

# ---------- 1) main 반영·태그·릴리즈 ----------
if has 'gh[[:space:]]+pr[[:space:]]+merge'; then
  ask "[main 반영] PR 병합입니다. CI 통과와 승인 여부를 확인하세요. (docs/process/git-flow.md)"
fi
if has 'gh[[:space:]]+release[[:space:]]+(create|delete|edit|upload)'; then
  ask "[릴리즈] GitHub 릴리즈 생성·수정·삭제입니다. (docs/process/06-release.md)"
fi
if has 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push'; then
  if has '(--force|--force-with-lease|[[:space:]]-f([[:space:]"]|$|\\))'; then
    ask "[main 반영] force push입니다. 원격 이력을 덮어씁니다."
  fi
  if has '(--delete|[[:space:]]-d[[:space:]]|[[:space:]]:[A-Za-z0-9])'; then
    ask "[삭제] 원격 브랜치·태그 삭제입니다."
  fi
  if has '(--tags|--follow-tags|refs/tags/|[[:space:]]v[0-9]+\.[0-9]+)'; then
    ask "[릴리즈] 버전 태그 push입니다. 릴리즈 워크플로가 실행될 수 있습니다. (docs/process/06-release.md)"
  fi
  if printf '%s' "$input" | grep -Eq '(^|[^A-Za-z0-9_./-])(main|master)([^A-Za-z0-9_./-]|$)'; then
    ask "[main 반영] main 브랜치 push입니다. 직접 반영이 허용된 변경(문서만 수정 등)인지 확인하세요. (docs/process/git-flow.md)"
  fi
  if ! has '(feature/|fix/|docs/|HEAD:)'; then
    branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)"
    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
      ask "[main 반영] 현재 브랜치가 $branch 입니다. main에 직접 push하게 됩니다. (docs/process/git-flow.md)"
    fi
  fi
fi

# ---------- 2) 삭제·되돌리기 불가 ----------
if has '(^|[^A-Za-z0-9_-])rm[[:space:]]+(-[A-Za-z]*[rR][A-Za-z]*|--recursive)'; then
  ask "[삭제] 재귀 삭제(rm -r)입니다. 대상 경로를 확인하세요."
fi
if has 'Remove-Item[^|;&]*-(Recurse|r)([[:space:]"]|$|\\)' || has '(rmdir|rd)[[:space:]]+/s' || has 'del[[:space:]]+/[sq]'; then
  ask "[삭제] 재귀 삭제입니다. 대상 경로를 확인하세요."
fi
if has 'git[[:space:]]+reset[[:space:]]+[^|;&]*--hard' || has 'git[[:space:]]+clean[[:space:]]+-[A-Za-z]*f'; then
  ask "[삭제] 커밋되지 않은 작업을 지우는 명령입니다 (reset --hard / clean -f)."
fi
if printf '%s' "$input" | grep -Eq 'git[[:space:]]+branch[[:space:]]+[^|;&]*-D' || has 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]"]|$|\\)' || has 'git[[:space:]]+stash[[:space:]]+(drop|clear)'; then
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
