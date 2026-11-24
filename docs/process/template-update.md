# 템플릿 업데이트

이 프로젝트를 만든 템플릿([huny4daniel/huny4daniels-TEMPLATE](https://github.com/huny4daniel/huny4daniels-TEMPLATE))이 갱신되면, 프로젝트에서 `/adopt`를 실행해 반영한다 (업데이트 모드). copier·cruft 같은 템플릿 도구와 같은 방식이다: **적용한 템플릿 버전을 기록해 두고, 그 이후 템플릿에서 바뀐 부분만 가져온다.**

`/adopt`는 실행 시점의 최신 템플릿에 있는 이 문서를 기준으로 동작한다. 아래 목록을 고치면 다음 업데이트부터 반영된다.

## 버전 기록: `.template-version`

```
repo=huny4daniel/huny4daniels-TEMPLATE
commit=<적용한 템플릿 커밋 SHA>
date=YYYY-MM-DD
```

- 새 프로젝트 생성(`/adopt` 새 프로젝트 모드, `new-project.ps1`)과 기존 프로젝트 도입 때 자동으로 만든다. GitHub "Use this template"으로 만든 경우 0단계에서 만든다.
- 업데이트를 반영할 때마다 갱신한다. 사람이 고치지 않는다.

## 파일 소유 구분

| 구분 | 파일 | 업데이트 방식 |
|---|---|---|
| **템플릿 소유** — 절차·도구. 프로젝트에서 고치지 않는다 | `docs/PROCESS.md`, `docs/README.md`, `docs/process/*`, `docs/templates/*`, `.claude/commands/*`, `.claude/hooks/*.sh`, `.github/ISSUE_TEMPLATE/*`, `.github/pull_request_template.md`, `.editorconfig` | 새 버전으로 교체 (추가·삭제 포함). 단, 기록된 버전 이후 프로젝트에서 직접 고친 파일이면 3-way 병합 |
| **프로젝트 소유** — 프로젝트 내용을 채운 파일 | `AGENTS.md`, `CLAUDE.md`, `docs/STATUS.md`, `.claude/hooks/checks.env`, `.claude/settings.json`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `.github/workflows/*`, `.gitignore`, `.gitattributes`, `.env.example`, `docs/product/*`, `docs/architecture/*`, `docs/adr/*`, `docs/plans/*`, `docs/runbooks/*`, `docs/postmortems/*`, `docs/retros/*`, `apps/`, `packages/`, `tools/` | **덮어쓰지 않는다.** 템플릿 쪽에서 구조가 바뀐 경우(새 섹션, 새 설정 키, 새 훅, 새 import)만 프로젝트 내용을 유지한 채 추가하는 변경을 제안한다 |
| 제외 | 템플릿 전용: `tools/scripts/new-project.ps1`, `.github/README.md`(템플릿 소개), `.github/ROADMAP.md`(템플릿 개선 계획) | 가져오지 않는다 |

목록에 없는 새 파일이 템플릿에 생기면 템플릿 소유로 보고 추가하되, 요약에 따로 표시한다.

**규칙**: 절차·명령·훅을 프로젝트에 맞게 바꾸고 싶으면 템플릿 소유 파일을 직접 고치지 말고, 프로젝트 소유 파일(AGENTS.md, checks.env, settings.json)에서 조정한다. 템플릿 자체를 바꿀 일이면 템플릿 저장소를 고친다.

## 업데이트 절차 (`/adopt`가 수행)

1. 최신 템플릿을 임시 폴더에 받고, `.template-version`의 커밋(기준)과 최신 커밋을 비교한다. 같으면 "최신"이라고 알리고 끝낸다.
2. `git diff --name-status <기준>..<최신>`으로 템플릿에서 바뀐 파일을 구하고, 위 표로 분류한다.
3. 템플릿 소유 파일마다 프로젝트 파일이 기준 버전과 같은지 확인한다.
   - 같다 → 최신으로 교체 (템플릿에서 삭제됐으면 삭제)
   - 다르다(프로젝트에서 고침) → `git merge-file`로 3-way 병합. 충돌이 나면 해당 부분을 보여주고 [질문]한다.
4. 프로젝트 소유 파일은 템플릿 쪽 변경(`git diff <기준>..<최신> -- <파일>`)을 읽고, 구조 변경이 있으면 프로젝트 내용을 지키며 반영할 수정안을 만든다.
5. 바뀌는 파일 목록, 변경 요약(템플릿 커밋 메시지 기준), 병합·충돌 항목, 프로젝트 소유 파일 수정안을 한 화면으로 보여주고 [승인 요청]한다.
6. 승인되면 `docs/template-update-<최신 짧은 SHA>` 브랜치에서 적용 → `.template-version` 갱신 → 커밋 → PR (docs/process/git-flow.md). 훅이 바뀌었으면 셸 명령 하나로 훅 동작을 확인한다.
7. STATUS.md 결정 기록에 "템플릿 업데이트 <기준>→<최신>"을 남긴다.

기준 커밋을 알 수 없으면(`.template-version` 없음) 템플릿 소유 파일을 최신과 파일 단위로 비교해 다른 것을 모두 보여주고, 하나씩 교체 여부를 [질문]한다. 끝나면 `.template-version`을 만든다.

## 업데이트 알림

`/next`는 `.template-version`이 있으면 하루 한 번 최신 템플릿 커밋을 확인하고(`gh api repos/<repo>/commits/main --jq .sha`, 확인 날짜는 `.claude/.template-check`에 기록, git 제외), 더 새로우면 업데이트를 한 줄로 [제안]한다. 진행 중인 작업이 있으면 그 작업이 끝난 뒤로 미룬다.
