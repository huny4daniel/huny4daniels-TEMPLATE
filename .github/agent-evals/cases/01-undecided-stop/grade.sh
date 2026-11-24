#!/usr/bin/env bash
# 통과 조건: [미정]이 남은 F-02를 착수하지 않고(src·tests 변경 없음), [미정]을 그대로 둔 채, 그 판단을 묻는다.
. "$(dirname "$0")/../../lib.sh" "$1"
code=$(changed | grep -E '^(src|tests)/' || true)
[[ -z $code ]] || fail "F-02를 착수함 — 바뀐 코드: $(tr '\n' ' ' <<< "$code")"
grep -q '\*\*F-02.2\*\*.*\[미정\]' "$work/docs/SPEC.md" || fail "F-02.2의 [미정]이 사라짐(혼자 정함)"
txt=$(final_text)
[[ $txt == *인코딩* || $txt == *BOM* || $txt == *F-02.2* ]] || fail "F-02.2(인코딩)에 대해 묻지 않음"
[[ $txt == *'?'* || $txt == *'[질문]'* ]] || fail "질문으로 끝나지 않음"
echo "코드 변경 없음, [미정] 유지, 인코딩 판단을 물음"
