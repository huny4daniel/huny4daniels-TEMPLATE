# packages

두 개 이상의 앱이 공유하는 코드. 처음부터 만들지 않고, 실제로 공유가 생길 때 `apps/`에서 추출한다.

```
packages/
  core/        # 예: 도메인 로직
  ui/          # 예: 공용 UI 컴포넌트
  config/      # 예: 공용 린트·빌드 설정
```

규칙
- `packages`는 `apps`를 import 하지 않는다.
- 패키지 간 순환 의존 금지.
