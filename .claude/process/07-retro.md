# 7단계: 운영·회고

관행: KPT 회고, Runbook, Blameless Postmortem

- **회고**: 마일스톤이 끝나면 Claude가 KPT(Keep / Problem / Try) 질문을 던지고 `docs/retros/`에 기록한다(템플릿 `.claude/templates/retrospective.md`). Try 항목은 AGENTS.md, 절차 문서, 템플릿에 반영을 제안한다.
  - **spec 돌아보기**: SPEC.md 변경 이력에서 이번 마일스톤에 자주 바뀐 기능과 그 이유를 짚는다(처음에 무엇을 몰랐는가). 남아 있는 `[제안]`·`[미정]`과 백로그를 정리할지 [질문]한다.
- **lite일 때**: 회고는 `docs/retros/` 대신 STATUS.md 세션 로그에 KPT 세 줄(spec 돌아보기 포함)로 남긴다. Runbook·Postmortem이 처음 필요해지면 템플릿 저장소에서 템플릿을 가져온다.
- **Runbook**: 배포·롤백·자주 생기는 문제 대응을 `docs/runbooks/`에 둔다(템플릿 `runbook.md`).
- **Postmortem**: 사용자 영향이 있던 문제는 비난 없는(Blameless) 형식으로 기록한다(템플릿 `postmortem.md`).

## 다음 방향

Claude가 [제안]하고 사람이 고른다:

- 다음 마일스톤이 있으면 → [03-plan.md](03-plan.md) (새로운 큰 기능이면 [01-idea-spec.md](01-idea-spec.md)대로 SPEC.md에 기능 소절을 먼저 추가)
- 계획된 기능이 없고 버그·소소한 개선이 중심이면 → [maintenance.md](maintenance.md) (STATUS.md 모드를 "유지보수"로)
- 더 진행하지 않기로 하면 → 아래 "프로젝트 종료"

## 프로젝트 종료 (선택)

1. README 상단에 상태(유지보수 중단, 보관됨)와 마지막 버전을 적는다.
2. STATUS.md 모드를 "종료"로 바꾸고 마지막 회고를 남긴다.
3. 열린 이슈를 정리(닫기 또는 라벨)하고 GitHub 저장소를 Archive 처리한다 ([요청] — 사람이 결정).
