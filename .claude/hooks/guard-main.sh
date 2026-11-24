#!/usr/bin/env bash
# PreToolUse 훅: main 반영·태그·릴리즈처럼 되돌리기 어려운 Git/GitHub 명령을 실행하기 전에
# 사람 확인을 받는다 (막지 않고 permissionDecision "ask").
# 대상: main/master push, 현재 브랜치가 main/master일 때의 push, 태그 push, force push,
#       원격 브랜치·태그 삭제, gh pr merge, gh release create/delete/edit
# 외부 도구(jq 등) 없이 bash + grep만 사용한다.

input="$(cat)"

ask() {
  reason="$1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

has() { printf '%s' "$input" | grep -Eq -- "$1"; }

if has 'gh[[:space:]]+pr[[:space:]]+merge'; then
  ask "PR 병합(main 반영)입니다. CI 통과와 승인 여부를 확인하세요. (docs/process/git-flow.md)"
fi

if has 'gh[[:space:]]+release[[:space:]]+(create|delete|edit)'; then
  ask "GitHub 릴리즈 생성·수정·삭제입니다. 릴리즈 승인 여부를 확인하세요. (docs/process/06-release.md)"
fi

if has 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push'; then
  if has '(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$|\\))'; then
    ask "force push입니다. 원격 이력을 덮어씁니다."
  fi
  if has '(--delete|[[:space:]]-d[[:space:]]|[[:space:]]:[A-Za-z0-9])'; then
    ask "원격 브랜치·태그 삭제입니다."
  fi
  if has '(--tags|--follow-tags|refs/tags/|[[:space:]]v[0-9]+\.[0-9]+)'; then
    ask "버전 태그 push입니다. 릴리즈 워크플로가 실행될 수 있습니다. (docs/process/06-release.md)"
  fi
  if has '(^|[^A-Za-z0-9_./-])(main|master)([^A-Za-z0-9_./-]|$)'; then
    ask "main 브랜치 push입니다. 직접 반영이 허용된 변경(문서만 수정 등)인지 확인하세요. (docs/process/git-flow.md)"
  fi
  # 브랜치를 명시하지 않은 push: 현재 브랜치가 main/master면 확인
  if ! has '(feature/|fix/|docs/|HEAD:)'; then
    dir="${CLAUDE_PROJECT_DIR:-.}"
    branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
      ask "현재 브랜치가 $branch 입니다. main에 직접 push하게 됩니다. (docs/process/git-flow.md)"
    fi
  fi
fi

exit 0
