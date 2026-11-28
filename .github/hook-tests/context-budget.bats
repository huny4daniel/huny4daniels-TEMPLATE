#!/usr/bin/env bats
# 컨텍스트 예산 (템플릿 전용 — ROADMAP D3)
# 세션마다 자동 로드되는 문서(CLAUDE.md가 import하는 것)가 템플릿 상태에서 상한을 넘지 않는지 검사한다.
# 규칙을 추가해 상한을 넘으면: 상세는 .claude/process/ 단계 문서로 옮기고 PROCESS.md에는 한 줄과 링크만 둔다.
# 상한을 올려야 한다면 이유를 ROADMAP D3에 적는다.

ROOT="$BATS_TEST_DIRNAME/../.."

# 바이트 기준 (한글은 UTF-8로 3바이트)
TOTAL_MAX=16896  # ROADMAP D3 "상한 조정"
declare -gA FILE_MAX=(
  [CLAUDE.md]=1024
  [AGENTS.md]=5120
  [.claude/process/PROCESS.md]=10240
  [docs/STATUS.md]=2560
)

size_of() { wc -c < "$ROOT/$1" | tr -d ' '; }

@test "each auto-loaded file stays under its budget" {
  local over=""
  for f in "${!FILE_MAX[@]}"; do
    local n; n=$(size_of "$f")
    if (( n > FILE_MAX[$f] )); then over+="$f: ${n} > ${FILE_MAX[$f]} bytes"$'\n'; fi
  done
  [[ -z $over ]] || { printf '자동 로드 문서 예산 초과:\n%s' "$over"; return 1; }
}

@test "auto-loaded total stays under budget" {
  local total=0
  for f in "${!FILE_MAX[@]}"; do total=$(( total + $(size_of "$f") )); done
  (( total <= TOTAL_MAX )) || { echo "자동 로드 합계 ${total} > ${TOTAL_MAX} bytes"; return 1; }
}

@test "CLAUDE.md imports exactly the budgeted files" {
  # 자동 로드 대상이 늘면 이 예산 표도 함께 늘려야 한다 (SPEC.md는 필요할 때만 읽는다 — 크기가 프로젝트마다 크게 다름)
  # 정렬 순서가 로캘마다 달라지지 않도록 C 로캘로 양쪽을 정렬해 비교한다
  local imports want
  imports=$(grep -oE '^@[^[:space:]]+' "$ROOT/CLAUDE.md" | sed 's/^@//' | LC_ALL=C sort | tr '\n' ' ')
  want=$(printf '%s\n' "${!FILE_MAX[@]}" | grep -v '^CLAUDE.md$' | LC_ALL=C sort | tr '\n' ' ')
  [[ $imports == "$want" ]] || { echo "CLAUDE.md import: $imports / 예산 표: $want"; return 1; }
}
