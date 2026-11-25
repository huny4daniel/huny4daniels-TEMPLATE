# 기여 가이드

작업 흐름 전체는 [.claude/process/git-flow.md](.claude/process/git-flow.md)(GitHub Flow)를 따른다.

## 브랜치

- `main`은 항상 배포 가능한 상태를 유지한다.
- 코드가 바뀌는 작업은 브랜치 + PR: `feature/<이슈번호>-<짧은-이름>`, `fix/<이슈번호>-<짧은-이름>`, `docs/<짧은-이름>`. 써 봐야 아는 기능의 프로토타입은 `spike/<F-ID>-<짧은-이름>`이고 병합하지 않는다
- `main`에는 직접 커밋하지 않는다. 문서만 바뀌어도 브랜치 + PR(진행 중인 작업이 있으면 그 브랜치에 함께), 릴리즈 준비는 `release/vX.Y.Z` 브랜치.
- 로컬 커밋은 자유롭게, 원격 `main`에는 squash merge로 PR 하나 = 커밋 하나.
- 브랜치 수명은 짧게(가능하면 1~3일), 작은 단위로 자주 병합한다.

## 커밋 메시지

- 한국어, 첫 줄은 한 줄 요약
- 빈 줄 후 `- 항목` 형식으로 변경 사항 나열
- prefix(feat:, fix: 등) 없이 내용만 작성
- 한 커밋 = 하나의 논리적 변경

## Pull Request

1. `.github/pull_request_template.md`의 체크리스트를 채우고, 본문에 `Closes #<이슈번호>`를 넣는다.
2. CI(테스트·린트·빌드)가 통과해야 병합한다.
3. 구조적 결정이 포함되면 ADR 링크를 첨부한다.
4. 병합은 squash merge를 기본으로 하고, 병합 커밋 메시지도 위 커밋 규칙을 따른다.
5. 병합 후 브랜치를 삭제한다.

## 버전과 릴리즈

- 버전은 SemVer `vMAJOR.MINOR.PATCH` 태그로 관리하고, 태그는 `main`에서 붙인다.
- 릴리즈 방식(빌드·배포 방법)은 프로젝트마다 2단계에서 정해 ADR로 기록한다: {{릴리즈 ADR 링크}}
- 릴리즈 전 `CHANGELOG.md`의 `[Unreleased]`를 버전 섹션으로 옮긴다.
- 절차 상세: [.claude/process/06-release.md](.claude/process/06-release.md)
