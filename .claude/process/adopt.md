# 기존 프로젝트 도입

이미 진행 중인 프로젝트에는 템플릿을 덮어쓰지 않고 단계적으로 도입한다. `/adopt` 명령으로 진행한다. `/adopt`는 폴더 상태를 보고 세 경로 중 하나로 동작한다:

| 경로 | 판단 기준 | 문서 |
|---|---|---|
| 업데이트 | `.template-version` 있음, 또는 `.claude/process/PROCESS.md`·`docs/STATUS.md`가 함께 있음 | [template-update.md](template-update.md) |
| 새 프로젝트 | 소스 코드·커밋 없음 (README·LICENSE·.gitignore 정도만) | [00-init.md](00-init.md) → `/kickoff` |
| 기존 프로젝트 도입 | 그 외 | 이 문서 |

`/adopt`는 아직 템플릿이 없는 폴더에서 실행해야 하므로 이 저장소가 아니라 플러그인([huny4daniels-claude-plugin](https://github.com/huny4daniel/huny4daniels-claude-plugin))으로 배포한다. 컴퓨터마다 한 번 설치한다 (비공개 저장소라 `gh auth login` 필요):

```bash
claude plugin marketplace add huny4daniel/huny4daniels-claude-plugin
claude plugin install project-process@huny4daniels
```

## 도입 원칙

1. **비침습 추가** — 문서·에이전트 설정·이슈/PR 템플릿만 추가한다. 이미 있는 파일(CLAUDE.md, AGENTS.md, README, .gitignore, CI, release 워크플로)은 덮어쓰지 않고 필요한 부분만 합친다.
2. **역방향 문서화** — 코드에서 현재 상태를 읽어 문서를 만든다. Claude가 초안을 쓰고 사람은 확인만 한다.
   - `docs/architecture/overview.md`: 현재 구조
   - `docs/adr/`: 이미 내린 주요 결정을 사후 기록 (상태 Accepted, 맥락에 "사후 기록"이라고 명시)
   - `docs/SPEC.md`: 코드에서 읽히는 기능을 소절로, 동작을 시나리오로 적되 모두 `[제안]`으로 둔다 — 코드가 그렇게 동작한다고 해서 의도한 동작이라는 보장은 없으므로 사람이 확인해 `[확정]`으로 바꾼다. 목표·비목표는 [질문]한다. 이미 테스트가 있는 동작은 상태 `Done`, 테스트 이름·주석에 시나리오 ID를 붙이는 작업은 별도 작업으로 [제안]한다
   - `AGENTS.md`: 실제 명령어·스택으로 자리표시자 채우기
3. **git 훅** — `.githooks/`를 추가하고 `git config core.hooksPath .githooks`를 켤지 [질문]한다. 프로젝트에 이미 `core.hooksPath`나 husky·lefthook 같은 훅 관리 도구가 있으면 덮어쓰지 않고, 기존 훅에서 `.githooks/pre-commit`·`pre-push`를 호출하는 방법을 [제안]한다.
4. **현재 위치 결정** — STATUS.md에 단계와 모드를 정한다. 대개 4단계(개발 중) 또는 유지보수 모드다. 0~2단계는 역방향 문서로 완료 처리한다.
5. **폴더 구조는 옮기지 않는다** — 기존 코드를 `apps/`로 옮기는 것은 빌드·릴리즈 경로를 바꾸는 위험한 작업이다. 앱이 둘 이상이 되거나 공유 코드가 생길 때 ADR을 쓰고 별도 작업으로 `git mv`(이력 보존)해 옮긴 뒤 빌드·릴리즈를 검증한다.
