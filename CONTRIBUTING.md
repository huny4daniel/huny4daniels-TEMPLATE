# 기여 가이드

## 브랜치

- `main`은 항상 배포 가능한 상태를 유지한다 (trunk-based).
- 작업 브랜치: `feature/<짧은-설명>`, `fix/<짧은-설명>`, `docs/<짧은-설명>`
- 브랜치 수명은 짧게(가능하면 1~3일), 작은 단위로 자주 병합한다.

## 커밋 메시지

- 한국어, 첫 줄은 한 줄 요약
- 빈 줄 후 `- 항목` 형식으로 변경 사항 나열
- prefix(feat:, fix: 등) 없이 내용만 작성

## Pull Request

1. `.github/pull_request_template.md`의 체크리스트를 채운다.
2. CI(테스트·린트·빌드)가 통과해야 병합한다.
3. 구조적 결정이 포함되면 ADR 링크를 첨부한다.

## 버전과 릴리즈

- SemVer `vMAJOR.MINOR.PATCH` 태그를 push하면 `.github/workflows/release.yml`이 빌드·배포한다.
- 릴리즈 전 `CHANGELOG.md`의 `[Unreleased]`를 버전 섹션으로 옮긴다.
- 절차 상세: [docs/PROCESS.md](docs/PROCESS.md) 6단계
