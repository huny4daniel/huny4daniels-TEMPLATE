# 0단계: 초기화

| Claude | 사람 |
|---|---|
| 자리표시자·STATUS.md 상태 점검, 프로젝트 이름 확인 | 저장소 생성(템플릿 또는 `/adopt`), 원격 연결 |

- 프로젝트 이름 자리표시자(`{{PROJECT_NAME}}`, `{{제품 이름}}`)를 채운다. `docs/adr/0001-*.md`와 STATUS.md의 날짜(`YYYY-MM-DD`)를 오늘 날짜로 바꾼다.
- 템플릿 전용 파일이 복사돼 있으면 지운다. 목록은 `.template-only`에 있다(GitHub "Use this template"으로 만들면 이 파일도 함께 복사되므로, 그 목록대로 지우고 `.template-only` 자신도 지운다). 특히 `.github/README.md`가 남아 있으면 GitHub 저장소 첫 화면에 루트 README 대신 템플릿 소개가 뜬다.
- `.template-version`이 없으면(GitHub "Use this template"으로 만든 경우) 만든다. `repo=`는 이 저장소를 만든 템플릿이다 — `gh repo view --json templateRepository --jq '.templateRepository // empty | "\(.owner.login)/\(.name)"'`로 찾고, 비어 있거나 `gh`를 쓸 수 없으면 `huny4daniel/huny4daniels-TEMPLATE`을 쓴다. `commit=`은 `git ls-remote https://github.com/<repo>.git refs/heads/main`의 최신 커밋이다 ([template-update.md](template-update.md)).
- 스택 관련 자리표시자(`{{INSTALL_COMMAND}}` 등)는 2단계에서 스택이 정해진 뒤 채운다.
- 원격 저장소가 없으면 만들지 [질문]한다.
- git 훅 켜기: `git config core.hooksPath .githooks` — Claude Code를 거치지 않은 커밋·push(사람, 다른 에이전트)에도 같은 린트·테스트·spec 커버리지 검사를 건다([guardrails.md](guardrails.md) "git 훅"). 컴퓨터마다 clone한 뒤 한 번 필요하다.
- 훅 동작 확인: 셸 명령을 하나 실행해 훅 오류가 없는지 본다. "Git Bash wasn't found" 오류가 나면 다른 작업보다 먼저 해결한다(설정 전까지 셸 명령이 막힌다). 사람에게 경로를 묻기 전에 먼저 찾는다 — [guardrails.md](guardrails.md) "Windows 주의"의 탐지 방법(PowerShell 도구 사용)으로 찾으면 사용자 설정에 넣고 재시작을 [요청]하고, 못 찾을 때만 Git 설치 폴더를 [질문]한다.

- **설명 수준 묻기**: 다른 질문보다 먼저 AskUserQuestion으로 묻고 STATUS.md "설명 수준"에 적는다(아래 표). 이미 적혀 있으면 묻지 않는다.

## 설명 수준

사람의 IT 경험에 맞춰 **대화에서** 용어를 얼마나 풀어 쓸지 정한다. 판단을 사람이 하려면 무엇을 고르는지 알아야 하기 때문이다.

| 수준 | 대상 | 쓰는 방식 |
|---|---|---|
| 입문 | 개발을 해 본 적이 거의 없다 | 전문 용어 대신 쉬운 말과 일상 비유를 먼저 쓰고, 원래 용어는 괄호로 한 번 붙인다. 예: "작업 사본(브랜치)을 따로 만들어 원본은 건드리지 않고 고칩니다", "변경 사항을 원본에 합칠지(PR 병합) 확인해 주세요". 선택지마다 고르면 무엇이 달라지는지 한 줄 덧붙인다 |
| 보통 | 개발 도구를 써 봤거나 배우는 중 | 용어는 그대로 쓰되, 처음 나오거나 드문 용어(ADR, squash merge, 마이그레이션 등)는 그 자리에서 한 줄로 풀이한다 |
| 전문 | 개발자 | 풀이 없이 쓴다 |

- **적용 범위**: 대화(브리핑, [질문]·[제안]·[승인 요청]·[요청]의 본문과 선택지). 코드·커밋 메시지·ADR·계획 문서는 표준 용어를 그대로 쓴다. SPEC.md는 원래 사용자 관점의 말로 쓰므로 수준과 관계없이 쉬운 말을 쓴다.
- **바꾸기**: 사람이 "더 쉽게", "용어 설명은 빼도 돼"처럼 말하면 그 자리에서 맞추고 STATUS.md 값도 고친다. 수준을 핑계로 판단에 필요한 정보(위험, 되돌릴 수 있는지)를 빼지 않는다.
- **비어 있을 때**: `/kickoff`·`/adopt`는 시작할 때, 이미 진행 중인 프로젝트는 `/next`가 한 번 묻는다. 답을 받기 전에는 "보통"으로 쓴다.

**게이트**: 저장소가 있고 STATUS.md의 현재 단계가 1로 바뀌었다. → [01-idea-spec.md](01-idea-spec.md)
