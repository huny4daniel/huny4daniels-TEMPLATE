# 0단계: 초기화

| Claude | 사람 |
|---|---|
| 자리표시자·STATUS.md 상태 점검, 프로젝트 이름 확인 | 저장소 생성(템플릿 또는 `/adopt`), 원격 연결 |

- 프로젝트 이름 자리표시자(`{{PROJECT_NAME}}`, `{{제품 이름}}`)를 채운다. `docs/adr/0001-*.md`와 STATUS.md의 날짜(`YYYY-MM-DD`)를 오늘 날짜로 바꾼다.
- 템플릿 전용 파일(`tools/scripts/new-project.ps1`, `.github/README.md`, `.github/ROADMAP.md`)이 복사돼 있으면 삭제한다. 특히 `.github/README.md`가 남아 있으면 GitHub 저장소 첫 화면에 루트 README 대신 템플릿 소개가 뜬다.
- `.template-version`이 없으면(GitHub "Use this template"으로 만든 경우) 만든다: `gh api repos/huny4daniel/huny4daniels-TEMPLATE/commits/main --jq .sha`로 최신 커밋을 넣는다 ([template-update.md](template-update.md)).
- 스택 관련 자리표시자(`{{INSTALL_COMMAND}}` 등)는 2단계에서 스택이 정해진 뒤 채운다.
- 원격 저장소가 없으면 만들지 [질문]한다.
- 훅 동작 확인: 셸 명령을 하나 실행해 훅 오류가 없는지 본다. "Git Bash wasn't found" 오류가 나면 [요청]으로 `CLAUDE_CODE_GIT_BASH_PATH` 설정을 안내한다 ([guardrails.md](guardrails.md)). 설정 전까지 셸 명령이 막히므로 다른 작업보다 먼저 해결한다.

**게이트**: 저장소가 있고 STATUS.md의 현재 단계가 1로 바뀌었다. → [01-idea-prd.md](01-idea-prd.md)
