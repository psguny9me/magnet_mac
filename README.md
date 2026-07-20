# WindowSnap

macOS용 창 분할·스냅 유틸리티입니다. 메뉴바에 상주하며, 단축키와 드래그 트리거로 창을 화면 비율에 맞게 배치할 수 있습니다.

- **최소 OS**: macOS 14.0 (Sonoma) 이상  
- **권장**: Apple Silicon (arm64), Xcode 16.x  
- **Bundle ID**: `com.windowsnap.app`  
- **버전**: 1.1.0 (빌드 2)

## 기능 요약

- 16가지 기본 레이아웃(절반, 1/4, 1/3, 2/3, 전체화면, 중앙, 복원 등)
- 전역 단축키(`CGEventTap`) 및 드래그 트리거 + 스냅 미리보기
- 메뉴바 아이콘·계층 메뉴, SwiftUI 설정(일반 / 단축키 / 레이아웃 / 고급)
- 최초 실행 시 온보딩(접근성 권한 안내)
- 커스텀 레이아웃 저장(UserDefaults + JSON)
- 다중 모니터·세로 모니터 대응(코어 로직)
- **클립보드 이미지 저장**: `⌃⌥S`(변경 가능)로 클립보드의 이미지를 PNG 파일로 저장
  - 저장 폴더 기본값은 데스크탑, **환경설정 → 일반 → 클립보드 이미지 저장**에서 변경
  - 파일명은 `클립보드 YYYY-MM-DD HH.mm.ss.png`, 중복 시 ` (2)` 등 자동 부여
  - 메뉴바의 **클립보드 이미지 저장 / 저장 폴더 열기** 항목으로도 실행 가능

## 요구 사항

| 항목 | 내용 |
|------|------|
| Xcode | 16.1 이상 권장 (`project.yml` 기준) |
| Swift | 6.0 |
| 아키텍처 | arm64 (프로젝트 설정 기준) |

## 빌드

저장소 루트에서:

```bash
cd /path/to/magnet_mac
xcodegen generate   # project.yml이 있을 때만
open WindowSnap.xcodeproj
```

또는 명령줄:

```bash
xcodebuild -project WindowSnap.xcodeproj -scheme WindowSnap -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

성공 시 제품은 보통 다음 경로에 생성됩니다.

- `build/Debug/WindowSnap.app` (로컬 `SYMROOT`/`CONFIGURATION_BUILD_DIR` 설정에 따라 다를 수 있음)

## 실행·권한

1. `WindowSnap.app` 실행 후 메뉴바에 아이콘이 표시됩니다(Dock에는 표시되지 않음, `LSUIElement`).
2. **손쉬운 사용(Accessibility)** 권한이 필요합니다. 창 이동·리사이즈, 전역 단축키에 사용됩니다.
3. 설정은 **⌘,** 또는 메뉴바 **환경설정…**에서 열 수 있습니다.

권한 거부 시: **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 앱을 허용하세요.

## 개인용 배포 패키지(ZIP)

Release 빌드 후 ZIP을 만드는 스크립트:

```bash
./scripts/package_personal_release.sh
```

결과물: `dist/WindowSnap-Release-YYYYMMDD.zip`  
압축을 풀고 `WindowSnap.app`을 **응용 프로그램** 폴더로 옮기면 됩니다.

다른 Mac에서 막힐 경우 격리 속성 제거:

```bash
xattr -dr com.apple.quarantine /Applications/WindowSnap.app
```

## 테스트

```bash
xcodebuild -project WindowSnap.xcodeproj -scheme WindowSnap -configuration Debug -destination 'platform=macOS,arch=arm64' build-for-testing
xcodebuild -project WindowSnap.xcodeproj -scheme WindowSnap -configuration Debug -destination 'platform=macOS,arch=arm64' test-without-building
```

(테스트 타겟 구성은 `project.yml` 및 `WindowSnapTests`를 참고하세요.)

## 프로젝트 구조(요약)

```
magnet_mac/
├── project.yml              # XcodeGen 정의
├── WindowSnap.xcodeproj
├── WindowSnap/              # 앱 소스
│   ├── App/
│   ├── Core/
│   ├── Events/
│   ├── UI/
│   └── Settings/
├── WindowSnapTests/
└── scripts/
    └── package_personal_release.sh
```

## 기술 스택

- SwiftUI(설정·온보딩), AppKit(메뉴바·오버레이)
- Accessibility API (`AXUIElement`), `CGEventTap`
- `@Observable` 기반 설정(`AppSettings`), UserDefaults

## 라이선스

이 저장소에 라이선스 파일이 없다면 사용 조건은 저장소 소유자에게 문의하세요.
