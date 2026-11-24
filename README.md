# {{PROJECT_NAME}}

> 한 줄 소개: 이 프로젝트가 누구의 어떤 문제를 해결하는가.

## 구성

| 경로 | 내용 |
|---|---|
| `apps/` | 배포·실행 단위 애플리케이션 (데스크톱, 웹, 모바일, 서버 등) |
| `packages/` | 여러 앱이 공유하는 라이브러리·모듈 |
| `tools/` | 빌드·배포·개발 보조 스크립트 |
| `docs/` | 기획·설계·결정 기록·운영 문서 ([docs/README.md](docs/README.md)) |
| `.github/` | CI/CD 워크플로, 이슈·PR 템플릿 |
| `.claude/` | Claude Code 프로젝트 설정·커스텀 명령 |

## 시작하기

```bash
# 사전 요구사항
# - (예) Python 3.12+, uv / Node 22+, pnpm / JDK 21

# 설치
{{INSTALL_COMMAND}}

# 실행
{{RUN_COMMAND}}

# 테스트
{{TEST_COMMAND}}
```

## 문서

- 진행 절차: [.claude/process/PROCESS.md](.claude/process/PROCESS.md)
- 현재 상태: [docs/STATUS.md](docs/STATUS.md)
- spec (무엇을 만드는가): [docs/SPEC.md](docs/SPEC.md)
- 아키텍처: [docs/architecture/overview.md](docs/architecture/overview.md)
- 결정 기록: [docs/adr/](docs/adr/)
- 변경 이력: [CHANGELOG.md](CHANGELOG.md)

## 라이선스

{{LICENSE}}
