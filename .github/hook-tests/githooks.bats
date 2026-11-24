#!/usr/bin/env bats
# git 훅 (.githooks/, ROADMAP E1) 회귀 테스트 — 템플릿 전용

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo feature/x)
  cd "$CLAUDE_PROJECT_DIR"
  mkdir -p .claude/hooks .githooks src tests docs
  cp "$HOOKS"/*.sh .claude/hooks/
  cp "$BATS_TEST_DIRNAME/../../.githooks/"* .githooks/
  chmod +x .githooks/*
  git config core.hooksPath .githooks
  git config user.email t@t; git config user.name t
  cat > lint.sh <<'EOF'
#!/usr/bin/env bash
rc=0; for f in "$@"; do grep -Hn 'BAD' "$f" && rc=1; done; exit $rc
EOF
  write_env 'bash lint.sh' '! grep -rq FAILTEST src' ''
  printf '.claude/hooks/.last-*\n.claude/metrics/\n' > .gitignore
  echo 'x = 1' > src/a.py
  git add -A && git commit -qm base --no-verify
  REMOTE=$(mktemp -d); git init -q --bare "$REMOTE"; git remote add origin "$REMOTE"
}

write_env() {
  cat > .claude/hooks/checks.env <<EOF
FILE_PATTERN='\.py\$'
LINT_CMD='$1'
TEST_CMD='$2'
SPEC_FILE='docs/SPEC.md'
SPEC_TEST_GLOB='$3'
EOF
}

ok() { "$@" >/dev/null 2>&1; }

@test "pre-commit: lint error in staged file blocks commit" {
  echo 'BAD = 1' >> src/a.py; git add src/a.py
  ! ok git commit -m bad || { echo "커밋이 막히지 않았다"; return 1; }
  sed -i 's/BAD/good/' src/a.py; git add src/a.py
  ok git commit -m fixed || { git commit -m fixed; return 1; }
}

@test "pre-commit: unstaged files and non-code files are not linted" {
  echo 'BAD = 1' >> src/a.py            # 스테이징 안 함
  echo 'BAD' > notes.txt; git add notes.txt
  ok git commit -m notes || { git commit -m notes; return 1; }
}

@test "pre-commit: empty LINT_CMD -> no-op" {
  write_env '' '' ''
  git add .claude/hooks/checks.env; git commit -qm env --no-verify
  echo 'BAD = 1' >> src/a.py; git add src/a.py
  ok git commit -m bad-allowed || { git commit -m bad-allowed; return 1; }
}

@test "pre-push: failing TEST_CMD blocks push, passing allows" {
  echo '# FAILTEST' >> src/a.py; git commit -qam t --no-verify
  ! ok git push -q origin feature/x || { echo "push가 막히지 않았다"; return 1; }
  sed -i 's/FAILTEST/fine/' src/a.py; git commit -qam t2 --no-verify
  ok git push -q origin feature/x || { git push origin feature/x; return 1; }
}

@test "pre-push: spec coverage failure blocks push" {
  write_env '' '' 'tests/**/*.py'
  printf '## 2. 기능\n\n### F-01 저장 — Must · Done\n\n- **F-01.1** 저장 [확정]\n' > docs/SPEC.md
  git add -A && git commit -qm spec --no-verify
  out=$(git push origin feature/x 2>&1) && { echo "push가 막히지 않았다"; return 1; }
  [[ $out == *"F-01.1"* ]] || { echo "$out"; return 1; }
  echo 'def test_f01_1(): pass' > tests/test_a.py; git add -A && git commit -qm test --no-verify
  ok git push -q origin feature/x || { git push origin feature/x; return 1; }
}

@test "pre-push: push to main prints a notice but is not blocked" {
  git branch -q main
  out=$(git push origin main 2>&1) || { echo "$out"; return 1; }
  [[ $out == *"main에 직접 push"* ]] || { echo "$out"; return 1; }
}
