# 6단계: 릴리즈

관행: SemVer, Keep a Changelog

1. Claude가 `docs/templates/release-checklist.md`로 점검하고 버전을 제안한다 (SemVer: 호환 깨짐 MAJOR / 기능 추가 MINOR / 수정 PATCH, 1.0.0 전에는 MINOR로 호환 깨짐 허용).
2. CHANGELOG `[Unreleased]` → `[X.Y.Z] - 날짜`.
3. **[승인 요청]** 후 커밋 → `git tag vX.Y.Z` → 커밋과 태그 함께 push → 릴리즈 ADR에서 정한 방식대로 배포 결과 확인. 태그는 항상 `main`에서 붙인다.
4. **[요청]** 배포물을 실제 설치해 확인.

→ [07-retro.md](07-retro.md)
