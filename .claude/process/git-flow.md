# Git 작업 흐름 (GitHub Flow)

`main`은 항상 배포 가능한 상태로 두고, 작업은 짧은 브랜치에서 PR로 합친다. 혼자 하는 프로젝트도 같은 흐름을 쓴다. PR이 CI 실행 지점이자 변경 기록이 되기 때문이다.

## 브랜치를 쓰는 경우와 main에 바로 커밋하는 경우

| 변경 | 방식 |
|---|---|
| 코드가 바뀌는 이슈 작업, 버그 수정 | 브랜치 + PR |
| 문서만 수정 (STATUS.md, 계획 문서, 오타, README) | `main`에 바로 커밋 가능 |
| 릴리즈 준비 커밋 (CHANGELOG 버전 이동) | `main`에 바로 커밋 가능, 태그는 `main`에서 |

애매하면 브랜치 + PR로 한다.

## 브랜치 → PR → 병합

1. `main`에서 최신 상태로 분기: `feature/<이슈번호>-<짧은-이름>`, `fix/<이슈번호>-<짧은-이름>`, `docs/<짧은-이름>`. 탐색용 프로토타입은 `spike/<F-ID>-<짧은-이름>`이고 병합하지 않는다([04-build.md](04-build.md) "탐색 경로").
2. 논리 단위로 커밋한다. 커밋 메시지 규칙은 CONTRIBUTING.md를 따른다.
3. PR 생성: PR 템플릿을 채우고 본문에 `Closes #<이슈번호>`를 넣어 병합 시 이슈가 닫히게 한다.
4. CI 통과를 확인한다. 실패하면 같은 브랜치에서 고친다.
5. 병합은 **squash merge**(이슈 하나 = `main` 커밋 하나)를 기본으로 하고, 병합 커밋 메시지도 커밋 규칙을 따른다. 병합 전 [승인 요청].
6. 병합 후 원격·로컬 브랜치를 삭제하고 `main`을 pull한다. 정리는 **병합이 확인된 뒤 별도 명령으로** 한다 — 병합 명령 뒤에 `;`로 브랜치 삭제를 이어 붙이거나 `| tail`로 종료 코드를 가리지 않는다.

**GitHub API가 오류를 돌려줄 때** (502, GraphQL 오류): 오류 응답이 작업 실패를 뜻하지는 않는다(요청은 처리되고 응답만 실패하는 경우가 있다). 같은 요청을 다시 보내기 전에 결과를 조회한다 — `gh api repos/<owner>/<repo>/pulls?head=<owner>:<브랜치>&state=all`, `gh api repos/<owner>/<repo>/pulls/<번호> --jq .merged`처럼 REST로 본다(`gh pr list`·`gh pr view`는 GraphQL이라 같은 장애에 걸린다). 재시도는 한두 번까지, 그래도 실패하면 멈추고 알린다. `gh pr merge` 대신 `gh api -X PUT .../pulls/<번호>/merge`로 병합해도 훅이 같은 CI 검사를 한다.

브랜치 수명은 짧게(가능하면 하루~사흘) 유지한다. 오래 걸리는 작업은 이슈를 더 작게 나눈다.

## main 보호

### 로컬 확인 훅 (기본으로 켜져 있음)

`.claude/hooks/guard.sh`가 main/master push, 태그 push, force push, 원격 삭제, `gh pr merge`, 릴리즈 변경 직전에 **사람 확인 창**을 띄운다. `gh pr merge`는 먼저 CI 상태를 조회해 실패·진행 중이면 병합을 거부한다 — 비공개 저장소에서도 "CI 통과 필수"가 기계적으로 지켜진다 (Claude를 거치지 않은 병합·push는 막지 못한다). 막지는 않으므로 문서만 main에 바로 커밋·push하는 경우도 확인 후 진행할 수 있다. 작업 브랜치(`feature/`, `fix/`, `docs/`) push와 PR 생성은 확인 없이 진행된다. 전체 대상과 조정 방법은 [guardrails.md](guardrails.md).

### GitHub 보호 규칙

3단계 Walking Skeleton에서 CI가 동작하면 Claude가 보호 규칙을 켤지 [질문]한다. 켜면 `gh api`로 ruleset을 만든다.

- 규칙: `main` 직접 push 금지(PR 필수), 병합 전 CI 상태 체크 통과 필수, force push·삭제 금지.
- 문서만 바로 커밋하는 경우를 위해 저장소 관리자 우회(bypass)를 허용할지, 모든 변경을 PR로 할지 함께 정한다.
- GitHub Free 플랜의 **비공개 저장소는 보호 규칙을 쓸 수 없다** (공개 저장소 또는 Pro 이상 필요). 이 경우 위의 로컬 확인 훅(main push 확인, CI 실패 시 병합 거부)이 대신하며, 그 결정을 STATUS.md 결정 기록에 남긴다. 보호 규칙과의 차이는 Claude를 거치지 않은 push·병합(터미널·IDE에서 직접)은 막지 못한다는 점이다. 그런 push에도 테스트·spec 커버리지 검사는 git 훅(`.githooks/pre-push`)이 건다([guardrails.md](guardrails.md) "git 훅").
