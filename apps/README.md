# apps

배포·실행 단위 애플리케이션. 폴더 하나 = 독립적으로 빌드·배포되는 앱 하나.

```
apps/
  desktop/     # 예: PyQt 데스크톱 앱
  android/     # 예: Android 앱 (Gradle)
  web/         # 예: 웹 프론트엔드
  server/      # 예: API 서버
```

규칙
- 앱끼리 서로 import 하지 않는다. 공유가 필요하면 `packages/`로 옮긴다.
- 각 앱 폴더에 자체 README(실행·빌드 방법)를 둔다.
