# 0단계: 초기화

| Claude | 사람 |
|---|---|
| 자리표시자·STATUS.md 상태 점검, 프로젝트 이름 확인 | 저장소 생성(템플릿 또는 `/adopt`), 원격 연결 |

- 프로젝트 이름 자리표시자(`{{PROJECT_NAME}}`, `{{제품 이름}}`)를 채운다. `docs/adr/0001-*.md`와 STATUS.md의 날짜(`YYYY-MM-DD`)를 오늘 날짜로 바꾼다.
- 템플릿 전용 파일 `tools/scripts/new-project.ps1`이 복사돼 있으면 삭제한다.
- 스택 관련 자리표시자(`{{INSTALL_COMMAND}}` 등)는 2단계에서 스택이 정해진 뒤 채운다.
- 원격 저장소가 없으면 만들지 [질문]한다.

**게이트**: 저장소가 있고 STATUS.md의 현재 단계가 1로 바뀌었다. → [01-idea-prd.md](01-idea-prd.md)
