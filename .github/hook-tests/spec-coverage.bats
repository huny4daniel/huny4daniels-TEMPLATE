#!/usr/bin/env bats
# spec-coverage.sh (ROADMAP G5) 회귀 테스트 — 템플릿 전용

load helpers

setup() {
  export CLAUDE_PROJECT_DIR
  CLAUDE_PROJECT_DIR=$(new_repo main)
  cd "$CLAUDE_PROJECT_DIR"
  mkdir -p .claude/hooks docs tests
  cp "$HOOKS"/*.sh .claude/hooks/
  write_env "tests/**/*.py"
  cat > docs/SPEC.md <<'EOF'
# SPEC: 테스트

| 항목 | 내용 |
|---|---|
| 규모 | lite |

<!-- lite: 한 줄 주석 -->

## 2. 기능

### F-01 로그인 — Must · Done

> 사용자로서 로그인하고 싶다.

- **F-01.1** 정상 로그인 [확정]
  - Given 가입한 사용자가
  - When 맞는 비밀번호로 로그인하면
  - Then 홈 화면이 보인다
- **F-01.2** 비밀번호 틀림 [확정]
- **F-01.3** 로딩 표시가 거슬리지 않음 [확정] (수동)

### F-02 내보내기 — Must · In Progress

- **F-02.1** CSV 저장 [확정]
- **F-02.2** 인코딩 선택 [미정] — 사용자가 고를지

### F-03 동기화 — Should · Planned

- **F-03.1** 충돌 시 최신 우선 [확정]

<!--
### F-09 예시 — Must · Done
- **F-09.1** 예시 [확정]
-->

## 3. 비기능 요구사항
EOF
  cat > tests/test_login.py <<'EOF'
def test_f01_1_login_ok():  # F-01.1
    pass
def test_f01_10_other():
    pass
EOF
  printf '.claude/hooks/.last-*\n.test-runs\n' > .gitignore
  git add -A && git -c user.email=t@t -c user.name=t commit -qm base
}

write_env() {
  cat > .claude/hooks/checks.env <<EOF
FILE_PATTERN='\.py\$'
FORMAT_CMD=''
LINT_CMD=''
TYPECHECK_CMD=''
TEST_CMD='echo run >> .test-runs'
SPEC_FILE='docs/SPEC.md'
SPEC_TEST_GLOB='$1'
EOF
}

cov() { bash .claude/hooks/spec-coverage.sh "$@"; }
add_test() { printf 'def test_%s():\n    pass\n' "$1" >> tests/test_login.py; }
set_scenario() { sed -i "s/\*\*$1\*\* \(.*\) \[[^]]*\]/**$1** \1 [$2]/" docs/SPEC.md; }

# ---------- spec-coverage.sh ----------

@test "spec-coverage: empty SPEC_TEST_GLOB -> no check" {
  write_env ""
  rc=0; out=$(cov) || rc=$?
  expect 0 "$rc" "종료 코드"; expect "" "$out" "출력"
}

@test "spec-coverage: Done scenario without test -> fail naming the ID" {
  rc=0; out=$(cov) || rc=$?
  expect 1 "$rc" "종료 코드"
  [[ $out == *"F-01.2 비밀번호 틀림"* && $out == *"f01_2"* ]] || { echo "$out"; return 1; }
  [[ $out != *"F-01.1 "* ]] || { echo "F-01.1은 테스트가 있다: $out"; return 1; }
}

@test "spec-coverage: test added -> pass" {
  add_test f01_2_wrong_password
  rc=0; out=$(cov) || rc=$?
  expect 0 "$rc" "종료 코드: $out"
}

@test "spec-coverage: F-01.10 does not satisfy F-01.1" {
  sed -i 's/def test_f01_1_login_ok():  # F-01.1/def test_login():/' tests/test_login.py
  add_test f01_2
  rc=0; out=$(cov) || rc=$?
  expect 1 "$rc" "종료 코드"
  [[ $out == *"F-01.1 정상 로그인"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: ID forms F-01.2, F01_2, f01_2 all recognized" {
  for form in '# F-01.2' 'def test_F01_2(): pass' 'def test_f01_2_x(): pass'; do
    git checkout -q -- tests/test_login.py
    echo "$form" >> tests/test_login.py
    cov >/dev/null || { echo "인식 실패: $form"; return 1; }
  done
}

@test "spec-coverage: manual and In Progress scenarios not required" {
  add_test f01_2
  # F-01.3 (수동), F-02 In Progress(테스트 없음, [미정] 있음)는 검사 대상이 아니다
  cov >/dev/null || { cov; return 1; }
}

@test "spec-coverage: proposed or undecided left in Done -> fail" {
  add_test f01_2
  set_scenario F-01.2 제안
  rc=0; out=$(cov) || rc=$?
  expect 1 "$rc" "제안"; [[ $out == *"[제안]이 남아 있다"* ]] || { echo "$out"; return 1; }
  set_scenario F-01.2 미정
  rc=0; out=$(cov) || rc=$?
  expect 1 "$rc" "미정"; [[ $out == *"[미정]이 남아 있다"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: explore feature cannot be Done" {
  add_test f01_2
  sed -i 's/^### F-03 동기화 — Should · Planned$/### F-03 동기화 — Should · Done [탐색]/' docs/SPEC.md
  sed -i 's/^- \*\*F-03.1\*\*.*$/- 알아낼 것: 충돌 처리 방식/' docs/SPEC.md
  rc=0; out=$(cov) || rc=$?
  expect 1 "$rc" "종료 코드"; [[ $out == *"[탐색] 기능은 Done이 될 수 없다"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: commented example ignored" {
  add_test f01_2
  rc=0; out=$(cov) || rc=$?
  expect 0 "$rc" "주석 안의 F-09가 검사되면 안 된다: $out"
  [[ $(cov --summary) != *F-09* ]] || { cov --summary; return 1; }
}

@test "spec-coverage: test-only ID reported but passes" {
  add_test f01_2
  echo '# F-07.2 old scenario' >> tests/test_login.py
  rc=0; out=$(cov) || rc=$?
  expect 0 "$rc" "종료 코드"
  [[ $out == *"F-07.2"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: summary lists features, counts and next steps" {
  rc=0; out=$(cov --summary) || rc=$?
  expect 0 "$rc" "종료 코드"
  for want in "(규모: lite)" "F-01 로그인 — Must · Done" "자동 2개 중 테스트 있음 1" "F-02 내보내기 — Must · In Progress" "[미정] 1" "Must 2개 중 Done 1개" "판단 필요: F-02"; do
    [[ $out == *"$want"* ]] || { echo "없음: $want"$'\n'"$out"; return 1; }
  done
}

@test "spec-coverage: summary suggests next Must without pending decisions" {
  set_scenario F-02.2 확정
  out=$(cov --summary)
  [[ $out == *"다음 후보: F-02 내보내기"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: template docs/SPEC.md skeleton passes" {
  cp "$BATS_TEST_DIRNAME/../../docs/SPEC.md" docs/SPEC.md
  cov >/dev/null || { cov; return 1; }
  out=$(cov --summary)
  [[ $out == *"F-01"* && $out == *"Planned"* ]] || { echo "$out"; return 1; }
}

@test "spec-coverage: speed" {
  local limit=1000; [[ $OSTYPE == msys* || $OSTYPE == cygwin* ]] && limit=4000
  local start=$EPOCHREALTIME
  for _ in 1 2 3; do cov >/dev/null || true; cov --summary >/dev/null; done
  local now=$EPOCHREALTIME; local ms=$(( (${now//[.,]/} - ${start//[.,]/}) / 6000 ))
  (( ms < limit )) || { echo "평균 ${ms}ms > ${limit}ms"; return 1; }
}

# ---------- check-turn.sh 연결 ----------

turn() { stop_input "$1" | bash .claude/hooks/check-turn.sh | decision; }
runs() { [[ -f .test-runs ]] && wc -l < .test-runs | tr -d ' ' || echo 0; }

@test "check-turn: spec-only change runs coverage, blocks, and skips TEST_CMD" {
  echo "" >> docs/SPEC.md
  expect block "$(turn false)" "Done인데 F-01.2 테스트 없음"
  expect 0 "$(runs)" "spec만 바뀌면 TEST_CMD는 돌지 않는다"
}

@test "check-turn: adding the missing test -> pass" {
  echo "" >> docs/SPEC.md
  expect block "$(turn false)" "첫 실패"
  add_test f01_2
  expect pass "$(turn false)" "테스트 추가 후"
}

@test "check-turn: no SPEC_TEST_GLOB -> spec change alone triggers nothing" {
  write_env ""
  echo "" >> docs/SPEC.md
  expect pass "$(turn false)" "검사 꺼짐"
}
