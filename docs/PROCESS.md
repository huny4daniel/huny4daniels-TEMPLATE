# 프로젝트 진행 절차 매뉴얼

백지 상태에서 시작하는 프로젝트를 코딩 에이전트와 함께 진행하기 위한 표준 절차.
새로운 방법론이 아니라 업계에서 널리 쓰이는 관행을 순서대로 엮은 것이다.

| 출처가 되는 관행 | 이 문서에서 쓰이는 곳 |
|---|---|
| PRD (Product Requirements Document) | 1단계 |
| Design Doc / RFC, C4 모델 | 2단계 |
| ADR (Architecture Decision Record, Michael Nygard 형식) | 2단계 이후 상시 |
| Walking Skeleton, 수직 슬라이스(Vertical Slice), MVP | 3단계 |
| Explore → Plan → Code → Commit (Anthropic Claude Code 권장 워크플로) | 4단계 |
| TDD, 테스트 피라미드, CI | 4~5단계 |
| Trunk-based development, 작은 PR | 4단계 |
| SemVer, Keep a Changelog | 6단계 |
| Runbook, Blameless Postmortem, 회고(Retrospective) | 7단계 |

---

## 전체 흐름

```
0 초기화 → 1 문제 정의 → 2 설계 → 3 계획 → [4 구현 ⇄ 5 검증] → 6 릴리즈 → 7 운영·회고
                                            ↑______________________________________|
```

각 단계는 **산출물**이 나와야 다음으로 넘어간다 (Stage-gate). 작은 프로젝트는 문서를 짧게 쓰되 단계를 건너뛰지는 않는다.

| 단계 | 산출물 | 템플릿 |
|---|---|---|
| 0 초기화 | 저장소, AGENTS.md 기본값 | — |
| 1 문제 정의 | `docs/product/PRD.md` | `templates/prd.md` |
| 2 설계 | `docs/architecture/overview.md`, ADR 0002~ | `templates/design-doc.md`, `templates/adr.md` |
| 3 계획 | 마일스톤, 이슈 목록, 첫 기능 계획 | `templates/plan.md` |
| 4 구현 | 코드, 테스트, 커밋 | `templates/plan.md` (진행 기록) |
| 5 검증 | CI 통과, 수동 확인 결과 | PR 템플릿 |
| 6 릴리즈 | 태그, CHANGELOG, 배포물 | `templates/release-checklist.md` |
| 7 운영·회고 | Runbook, Postmortem, 회고 | `templates/runbook.md`, `templates/postmortem.md`, `templates/retrospective.md` |

---

## 0단계: 초기화 (30분)

1. 템플릿 복사 → `git init` → 첫 커밋.
2. `README.md`, `AGENTS.md`의 `{{…}}` 자리표시자 중 지금 아는 것만 채운다. 모르는 칸은 남겨둔다.
3. 스택이 정해지면 워크스페이스 설정을 추가한다 (아래 "스택별 모노레포 도구" 참고).
4. 원격 저장소 생성 후 push.

**완료 조건**: 빈 저장소가 원격에 있고, 에이전트가 AGENTS.md를 읽을 수 있다.

---

## 1단계: 문제 정의 — PRD

목적: **무엇을, 왜** 만드는지 고정한다. 어떻게는 아직 쓰지 않는다.

1. `templates/prd.md`를 `docs/product/PRD.md`로 복사해 작성한다.
2. 반드시 채울 것: 문제, 대상 사용자, 목표/비목표(Non-goals), 핵심 사용자 시나리오, 성공 지표, 범위(MVP 경계).
3. 기능 요구사항에 **MoSCoW 우선순위**(Must / Should / Could / Won't)를 붙인다.

**에이전트 활용**: 아이디어를 설명하고 "PRD 템플릿 기준으로 빠진 항목과 모호한 점을 질문해줘"라고 요청 → 인터뷰 형식으로 채운다. 에이전트가 초안을 쓰게 하더라도 목표·비목표는 사람이 확정한다.

**완료 조건**: Must 항목만으로 MVP 범위가 명확하고, 비목표가 적혀 있다.

---

## 2단계: 설계 — Design Doc + ADR

목적: **어떻게** 만들지, 그리고 왜 그렇게 정했는지 기록한다.

1. `templates/design-doc.md`로 `docs/architecture/overview.md`를 작성한다.
   - 시스템 컨텍스트, 컴포넌트(= apps/packages 분할), 데이터 모델, 외부 연동.
   - 다이어그램은 C4 모델의 Context / Container 수준까지면 충분하다 (Mermaid 권장).
2. 되돌리기 비싼 결정마다 ADR을 하나씩 쓴다: 언어·프레임워크, 저장소(DB/파일), 배포 방식, 상태 관리 등.
   - 번호는 순차 증가, 한 번 승인된 ADR은 수정하지 않고 새 ADR로 대체(Superseded)한다.
3. 모노레포 분할 원칙:
   - 배포 단위 = `apps/` 하나.
   - 두 곳 이상에서 쓰면 `packages/`로 승격. 처음부터 쪼개지 않는다 (YAGNI).
   - 의존 방향은 `apps → packages`만 허용. `packages → apps`, `apps → apps` 금지.

**에이전트 활용**: Plan 모드에서 "PRD를 읽고 설계 대안 2~3개와 트레이드오프를 비교해줘" → 사람이 선택 → 선택 결과를 ADR로 작성시킨다.

**완료 조건**: overview.md와 핵심 ADR이 있고, 첫 구현에 필요한 기술 선택이 모두 끝났다.

---

## 3단계: 계획 — 마일스톤과 작업 분해

1. **Walking Skeleton**을 첫 마일스톤으로 잡는다: 모든 계층(UI → 로직 → 저장 → 빌드 → 배포)을 최소 기능으로 관통하는 실행 가능한 뼈대. CI와 release 워크플로도 이때 붙인다.
2. 이후 마일스톤은 **수직 슬라이스**(사용자가 체감하는 기능 하나를 끝까지)로 나눈다. 계층별(“DB 먼저 다 하고 UI”) 분할은 피한다.
3. 각 슬라이스를 GitHub Issue로 만들고(이슈 템플릿 사용), 이슈 하나 = PR 하나 = 에이전트 세션 하나 정도의 크기로 맞춘다.
4. 지금 착수할 이슈만 `templates/plan.md`로 상세 계획을 쓴다. 먼 미래 이슈는 제목 수준으로 둔다.

**Definition of Ready (착수 가능 조건)**
- [ ] 수용 기준(Acceptance Criteria)이 검증 가능한 문장으로 적혀 있다
- [ ] 의존하는 결정(ADR)이 끝났다
- [ ] 한 세션(수 시간) 안에 끝낼 크기다

---

## 4단계: 구현 — 에이전트 작업 루프

Anthropic이 권장하는 Claude Code 워크플로를 따른다.

```
Explore → Plan → Code → Verify → Commit
```

1. **Explore** — 관련 파일·문서를 읽게만 하고 아직 코드를 쓰지 않게 한다.
   예: "docs/plans/xxx.md와 관련 코드를 읽고 현재 구조를 요약해줘. 아직 수정하지 마."
2. **Plan** — Plan 모드(또는 `/plan` 명령)로 구현 계획을 받는다. 계획은 `docs/plans/<이슈번호>-<이름>.md`에 저장한다. 사람이 검토·수정 후 승인한다.
3. **Code** — 계획 단위로 구현. 테스트로 검증 가능한 로직은 **테스트 먼저**(TDD): 실패하는 테스트 작성 → 커밋 → 구현 → 통과.
4. **Verify** — 테스트·린트·타입 체크·빌드 실행. UI는 실제로 실행해 확인(스크린샷 등). 결과를 계획 문서의 진행 기록에 남긴다.
5. **Commit** — 논리 단위로 커밋, PR 생성. 사용자 영향이 있으면 CHANGELOG `[Unreleased]` 갱신.

**세션 운영 원칙**
- 한 세션 = 한 작업. 작업이 바뀌면 `/clear`. 이어서 할 일은 계획 문서에 적어두면 다음 세션이 그것을 읽고 재개한다.
- 같은 실수를 두 번 하면 AGENTS.md의 Gotchas에 추가한다 (지침은 짧고 구체적으로 유지).
- 방향이 틀어지면 빨리 멈추고(Esc) 되돌린 뒤 지시를 구체화한다. 잘못된 결과 위에 덧칠하지 않는다.
- 독립적인 작업은 git worktree로 분리해 병렬 세션을 돌릴 수 있다.
- 에이전트에게 맡길 때 지시에는 **목표, 관련 파일, 제약, 완료 조건(어떻게 검증할지)**을 포함한다.

**Definition of Done (완료 조건)**
- [ ] 수용 기준을 모두 만족
- [ ] 테스트 추가/수정, 전체 테스트 통과
- [ ] 린트·타입 체크·빌드 통과
- [ ] 필요한 문서(ADR, README, CHANGELOG) 갱신
- [ ] PR 리뷰(사람 또는 `/review`) 완료

---

## 5단계: 검증

- **테스트 피라미드**: 단위 테스트 다수 > 통합 테스트 일부 > E2E/수동 소수.
- **CI**: PR마다 `.github/workflows/ci.yml`에서 설치 → 린트 → 타입 체크 → 테스트 → 빌드. 실패한 PR은 병합하지 않는다.
- 모노레포에서는 변경된 패키지와 그 의존자만 테스트하는 것이 일반적이다 (Turborepo/Nx의 affected, 또는 경로 필터).
- 리뷰: 사람 리뷰가 어려우면 별도 세션의 에이전트에게 리뷰시킨다 (작성한 세션과 컨텍스트를 분리해야 객관적이다).

---

## 6단계: 릴리즈

1. `templates/release-checklist.md`를 따라 점검.
2. 버전 결정 (SemVer): 호환 깨짐 → MAJOR, 기능 추가 → MINOR, 버그 수정 → PATCH. 1.0.0 이전에는 MINOR를 호환 깨짐에 써도 된다.
3. CHANGELOG `[Unreleased]` → `[X.Y.Z] - 날짜`로 이동.
4. 커밋 → `git tag vX.Y.Z` → 커밋과 태그를 함께 push → `release.yml`이 빌드·배포.

---

## 7단계: 운영·회고

- **Runbook**: 배포, 롤백, 자주 생기는 장애 대응을 `docs/runbooks/`에 둔다.
- **Postmortem**: 사용자 영향이 있었던 문제는 비난 없는(Blameless) 형식으로 원인·재발 방지책을 기록한다.
- **회고**: 마일스톤마다 Keep / Problem / Try 형식으로 짧게. 나온 개선점은 AGENTS.md, 이 문서, 템플릿에 반영한다.

---

## 스택별 모노레포 도구 (표준 선택지)

| 스택 | 워크스페이스 | 태스크 러너 |
|---|---|---|
| JavaScript/TypeScript | pnpm workspaces (`pnpm-workspace.yaml`) | Turborepo 또는 Nx |
| Python | uv workspaces (루트 `pyproject.toml`의 `[tool.uv.workspace]`) | `uv run`, Makefile/justfile |
| Android/Kotlin/JVM | Gradle 멀티 프로젝트 (`settings.gradle.kts`) | Gradle |
| 혼합 | 언어별 워크스페이스를 각 앱 폴더에 두고 | 루트 Makefile/justfile로 통합 |

단일 앱 프로젝트도 같은 구조를 쓴다 (`apps/` 하나, `packages/` 비어 있음). 나중에 앱이 늘어도 구조를 바꿀 필요가 없다.

---

## 문서 위치 규칙

| 문서 | 위치 | 수명 |
|---|---|---|
| PRD | `docs/product/PRD.md` | 프로젝트 내내 갱신 |
| 아키텍처 개요 | `docs/architecture/overview.md` | 구조 변경 시 갱신 |
| 기능 설계 | `docs/architecture/<기능>.md` | 큰 기능만 |
| ADR | `docs/adr/NNNN-<제목>.md` | 불변 (대체만 가능) |
| 작업 계획 | `docs/plans/<이슈>-<이름>.md` | 작업 완료 후 보관 |
| Runbook | `docs/runbooks/<주제>.md` | 상시 갱신 |
| Postmortem | `docs/postmortems/YYYY-MM-DD-<제목>.md` | 불변 |
| 회고 | `docs/retros/YYYY-MM-DD-<마일스톤>.md` | 불변 |
