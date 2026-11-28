# Git 작업 흐름 (GitHub Flow)

`main`은 항상 배포 가능한 상태로 두고, 작업은 짧은 브랜치에서 PR로 합친다. 혼자 하는 프로젝트도 같은 흐름을 쓴다. PR이 CI 실행 지점이자 변경 기록이 되기 때문이다.

## 이력 원칙: 원격 `main`에는 PR 하나 = 커밋 하나

커밋은 **작업(요청 하나 또는 묶음)이 끝날 때 한 번** 한다 — 중간 단계마다 커밋하지 않는다. 한 세션에서 한 관련 작업은 **브랜치 하나, PR 하나**로 모아 병합 승인도 한 번에 받는다(큰 기능만 따로). 원격 `main`에는 **squash merge된 PR 커밋만** 올라간다. `main`에 직접 커밋·push하지 않는다 — 문서만 바뀌어도 마찬가지다.

| 변경 | 방식 |
|---|---|
| 코드가 바뀌는 이슈 작업, 버그 수정 | 브랜치 + PR |
| STATUS.md·계획 문서·CHANGELOG 갱신 | **진행 중인 작업 브랜치에 함께 커밋** → 그 PR과 함께 squash |
| 작업 브랜치가 없을 때의 기록 (세션 종료 STATUS 갱신 등) | 다음 작업 브랜치를 먼저 만들어 거기에 커밋한다. 다음 작업이 정해지지 않았으면 `docs/status-<YYYY-MM-DD>` 브랜치에 모아 두고, 다음 작업 브랜치를 그 위에서 분기하거나 문서만 모아 PR 하나로 올린다 |
| 문서만 수정 (오타, README) | `docs/<짧은-이름>` 브랜치 + PR |
| 릴리즈 준비 (CHANGELOG 버전 이동) | `release/vX.Y.Z` 브랜치 + PR, 병합 뒤 `main`에서 태그 ([06-release.md](06-release.md)) |

**push 시점** — 작업 브랜치는 매 커밋마다 push하지 않는다. push하는 때:
- PR을 만들 때(CI가 여기서 돈다), PR이 열린 뒤 CI 실패를 고쳤을 때
- 세션을 끝낼 때(`/wrap`) — 다른 컴퓨터에서 이어 가기 위한 백업

## 브랜치 → PR → 병합

1. `main`에서 최신 상태로 분기: `feature/<이슈번호>-<짧은-이름>`, `fix/<이슈번호>-<짧은-이름>`, `docs/<짧은-이름>`. 탐색용 프로토타입은 `spike/<F-ID>-<짧은-이름>`이고 병합하지 않는다([04-build.md](04-build.md) "탐색 경로").
2. 작업이 끝나면 한 번 커밋한다. 같은 PR에 이어서 할 일이 생기면 그것까지 마친 뒤 커밋한다. 여러 이슈를 한 PR로 묶을 때는 브랜치를 `feature/<짧은-이름>`으로 하고 본문에 `Closes #a`, `Closes #b`를 모두 적는다. 커밋 메시지 규칙은 CONTRIBUTING.md를 따른다. 브랜치 안의 커밋은 squash되므로 다듬지 않아도 된다 — 다듬을 곳은 PR 제목과 squash 커밋 메시지다.
3. PR 생성: PR 템플릿을 채우고 본문에 `Closes #<이슈번호>`를 넣어 병합 시 이슈가 닫히게 한다.
4. CI 통과를 확인한다. 실패하면 같은 브랜치에서 고친다.
5. 병합은 **squash merge만** 쓴다(PR 하나 = `main` 커밋 하나). squash 커밋 제목은 PR 제목, 본문은 브랜치 커밋 목록을 그대로 붙이지 않고 커밋 규칙대로 `- 항목`으로 다시 정리한다. 병합 전 [승인 요청].
6. 병합 후 원격·로컬 브랜치를 삭제하고 `main`을 pull한다. 정리는 **병합이 확인된 뒤 별도 명령으로** 한다 — 병합 명령 뒤에 `;`로 브랜치 삭제를 이어 붙이거나 `| tail`로 종료 코드를 가리지 않는다.

**GitHub API가 오류를 돌려줄 때** (502, GraphQL 오류): 오류 응답이 작업 실패를 뜻하지는 않는다(요청은 처리되고 응답만 실패하는 경우가 있다). 같은 요청을 다시 보내기 전에 결과를 조회한다 — `gh api repos/<owner>/<repo>/pulls?head=<owner>:<브랜치>&state=all`, `gh api repos/<owner>/<repo>/pulls/<번호> --jq .merged`처럼 REST로 본다(`gh pr list`·`gh pr view`는 GraphQL이라 같은 장애에 걸린다). 재시도는 한두 번까지, 그래도 실패하면 멈추고 알린다. `gh pr merge` 대신 `gh api -X PUT .../pulls/<번호>/merge`로 병합해도 훅이 같은 CI 검사를 한다.

브랜치 수명은 짧게(가능하면 하루~사흘) 유지한다. 오래 걸리는 작업은 이슈를 더 작게 나눈다.

## main 보호

### 로컬 확인 훅 (기본으로 켜져 있음)

`.claude/hooks/guard.sh`가 main/master push, 태그 push, force push, 원격 삭제, `gh pr merge`, 릴리즈 변경 직전에 **사람 확인 창**을 띄운다. `gh pr merge`는 먼저 CI 상태를 조회해 실패·진행 중이면 병합을 거부한다 — 비공개 저장소에서도 "CI 통과 필수"가 기계적으로 지켜진다 (Claude를 거치지 않은 병합·push는 막지 못한다). main push는 이력 원칙상 하지 않는다(확인 창이 뜨면 브랜치로 옮긴다). 작업 브랜치(`feature/`, `fix/`, `docs/`, `release/`) push와 PR 생성은 확인 없이 진행된다. 전체 대상과 조정 방법은 [guardrails.md](guardrails.md).

### GitHub 보호 규칙

3단계 Walking Skeleton에서 CI가 동작하면 Claude가 아래를 켤지 [질문]한다.

- **병합 방식 설정** (플랜과 관계없이 가능): squash만 허용하고 병합 뒤 브랜치를 자동 삭제한다 — `gh api -X PATCH repos/<owner>/<repo> -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false -F delete_branch_on_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY`. 이력 원칙을 GitHub 쪽에서 강제한다.
- **보호 규칙** (`gh api`로 ruleset): `main` 직접 push 금지(PR 필수), 병합 전 CI 상태 체크 통과 필수, force push·삭제 금지. 모든 변경이 PR로 가므로 관리자 우회는 두지 않는다.
- GitHub Free 플랜의 **비공개 저장소는 보호 규칙을 쓸 수 없다** (공개 저장소 또는 Pro 이상 필요). 이 경우 위의 로컬 확인 훅(main push 확인, CI 실패 시 병합 거부)이 대신하며, 그 결정을 STATUS.md 결정 기록에 남긴다. 보호 규칙과의 차이는 Claude를 거치지 않은 push·병합(터미널·IDE에서 직접)은 막지 못한다는 점이다. 그런 push에도 테스트·spec 커버리지 검사는 git 훅(`.githooks/pre-push`)이 건다([guardrails.md](guardrails.md) "git 훅").
