# 0단계: 초기화

| Claude | 사람 |
|---|---|
| 자리표시자·STATUS.md 상태 점검, 프로젝트 이름 확인 | 저장소 생성(템플릿 또는 `/adopt`), 원격 연결 |

- 프로젝트 이름 자리표시자(`{{PROJECT_NAME}}`, `{{제품 이름}}`)를 채운다. `docs/adr/0001-*.md`와 STATUS.md의 날짜(`YYYY-MM-DD`)를 오늘 날짜로 바꾼다.
- 템플릿 전용 파일이 복사돼 있으면 지운다. 목록은 `.template-only`에 있다(GitHub "Use this template"으로 만들면 이 파일도 함께 복사되므로, 그 목록대로 지우고 `.template-only` 자신도 지운다). 특히 `.github/README.md`가 남아 있으면 GitHub 저장소 첫 화면에 루트 README 대신 템플릿 소개가 뜬다.
- `.template-version`이 없으면(GitHub "Use this template"으로 만든 경우) 만든다: `gh api repos/huny4daniel/huny4daniels-TEMPLATE/commits/main --jq .sha`로 최신 커밋을 넣는다 ([template-update.md](template-update.md)).
- 스택 관련 자리표시자(`{{INSTALL_COMMAND}}` 등)는 2단계에서 스택이 정해진 뒤 채운다.
- 원격 저장소가 없으면 만들지 [질문]한다.
- git 훅 켜기: `git config core.hooksPath .githooks` — Claude Code를 거치지 않은 커밋·push(사람, 다른 에이전트)에도 같은 린트·테스트·spec 커버리지 검사를 건다([guardrails.md](guardrails.md) "git 훅"). 컴퓨터마다 clone한 뒤 한 번 필요하다.
- 훅 동작 확인: 셸 명령을 하나 실행해 훅 오류가 없는지 본다. "Git Bash wasn't found" 오류가 나면 다른 작업보다 먼저 해결한다(설정 전까지 셸 명령이 막힌다). 사람에게 경로를 묻기 전에 먼저 찾는다 — [guardrails.md](guardrails.md) "Windows 주의"의 탐지 방법(PowerShell 도구 사용)으로 찾으면 사용자 설정에 넣고 재시작을 [요청]하고, 못 찾을 때만 Git 설치 폴더를 [질문]한다.