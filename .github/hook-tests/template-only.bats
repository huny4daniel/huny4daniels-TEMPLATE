#!/usr/bin/env bats
# 템플릿 전용 목록(.template-only, ROADMAP H1) 검사 — 템플릿 전용

ROOT="$BATS_TEST_DIRNAME/../.."

entries() { grep -vE '^[[:space:]]*(#|$)' "$ROOT/.template-only" | sed 's/[[:space:]]*$//'; }

@test "template-only: every listed path exists" {
  local missing=""
  while IFS= read -r p; do
    [[ -e $ROOT/${p%/} ]] || missing+="$p "
  done < <(entries)
  [[ -z $missing ]] || { echo "목록에 있지만 없는 경로: $missing"; return 1; }
}

@test "template-only: the list is not duplicated elsewhere" {
  # 목록 항목을 셋 이상 나열한 파일은 목록을 따로 들고 있는 것으로 본다 (소개 문서·로드맵은 설명이라 제외)
  local f n p dup=""
  while IFS= read -r f; do
    case $f in .template-only|.github/README.md|.github/ROADMAP.md|.github/hook-tests/*) continue ;; esac
    n=0
    while IFS= read -r p; do
      [[ $p == .template-only ]] && continue
      grep -qF -- "${p%/}" "$ROOT/$f" && n=$((n + 1))
    done < <(entries)
    (( n >= 3 )) && dup+="$f($n) "
  done < <(cd "$ROOT" && git ls-files '*.md' '*.ps1' '*.sh' '*.yml')
  [[ -z $dup ]] || { echo "목록을 따로 들고 있는 파일: $dup — .template-only를 가리키게 바꾼다"; return 1; }
}

@test "template-only: generator and procedures read the list" {
  grep -q "'.template-only'" "$ROOT/tools/scripts/new-project.ps1"
  grep -q '\.template-only' "$ROOT/.claude/process/00-init.md"
  grep -q '\.template-only' "$ROOT/.claude/process/template-update.md"
}
