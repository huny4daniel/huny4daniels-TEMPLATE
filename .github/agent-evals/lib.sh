# 채점 공용 함수 — grade.sh가 불러온다.
work=$1
final_text() { python -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); print(d.get("result",""))' "$work/.eval-result.json" 2>/dev/null; }
changed() { git -C "$work" status --porcelain | cut -c4-; }
fail() { echo "$1"; exit 1; }
