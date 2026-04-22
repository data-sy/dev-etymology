# AGENTS.md — DevEtym 에이전트 작업 분배

> 각 에이전트는 담당 영역이 다르다. 병렬 개발 시엔 git worktree로 독립 브랜치에서 작업하고, 단일 에이전트 투입이면 main에서 feature 브랜치만 파서 진행한다.
> CLAUDE.md의 코딩 규칙·의존성 규칙이 모든 에이전트에 적용된다.

---

## 5-에이전트 체계

| 이름 | 담당 요약 |
|---|---|
| [services](#agent-services) | TermService 오케스트레이션, ClaudeAPIService 호출 인프라 |
| [data](#agent-data) | 모델 스키마, 번들 DB 컨텐츠, BundleDBService, 생성 스크립트 |
| [ui](#agent-ui) | 모든 View/ViewModel, 디자인 시스템(컬러·폰트), 접근성 |
| [settings](#agent-settings) | 설정 탭 (외관 모드, 앱 정보, 법적 고지) |
| [ai](#agent-ai) | AI 응답 품질 (프롬프트 엔지니어링·tool_use·thinking·caching) |

### 공통 의존성 규칙 (예외 없음)

- 모든 ViewModel은 `TermServiceProtocol`에만 의존
- ViewModel에서 `BundleDBService`, `ClaudeAPIService`, `modelContext` 직접 참조 금지
- SwiftData `@Query`를 View/ViewModel에서 직접 사용 금지
- `TermService`/`TermServiceProtocol`은 `@MainActor` 필수
- `TermEntry ↔ Term` 변환 시 `aliases`, `category` 보존

자세한 규칙은 CLAUDE.md, 화면별 상세 명세는 spec.md 참조.

---

## worktree 세팅 (병렬 작업 시)

```bash
git worktree add ../devetym-<agent-name> -b feat/<branch-name>
```

단일 에이전트 투입이면 worktree 없이 main에서 브랜치만 파도 충분하다.

---

## Agent: services

**담당 파일**
- `DevEtym/DevEtym/Services/TermService.swift`
- `DevEtym/DevEtym/Services/TermServiceProtocol.swift`
- `DevEtym/DevEtym/Services/ClaudeAPIService.swift` (HTTP 호출·파싱 뼈대, 에러 타입)
- `DevEtym/DevEtym/Services/ClaudeAPIError.swift`
- `DevEtym/DevEtym/Utils/EnvironmentKeys.swift`
- `DevEtym/DevEtymTests/TermServiceTests.swift`
- `DevEtym/DevEtymTests/ClaudeAPIServiceTests.swift` (네트워크·파싱 레이어 테스트)
- `DevEtym/DevEtymTests/Mocks/MockClaudeAPIService.swift`
- `Config.xcconfig` / `Config.sample.xcconfig` (API 키 배선)

**범위**
- 검색 오케스트레이션 (Bundle → SwiftData 캐시 → AI 폴백)
- 북마크·히스토리 CRUD
- Claude API 호출 인프라 (요청 생성, 응답 파싱 뼈대, 에러 매핑, API 키 검증)
- SwiftData 저장 정책 (Term upsert, SearchHistory upsert)

**ai 에이전트와의 경계**
- HTTP/파싱/에러 매핑 = services
- 프롬프트 내용, tool_use·thinking·caching 활용 = ai
- 양쪽이 겹치는 리팩터(예: tool_use 도입 시 파싱 로직 단순화)는 ai가 주도하되 services 규약(에러 타입, Protocol 시그니처)은 유지

**규칙**
- `@MainActor` 필수 (SwiftData mainContext는 메인 스레드 전용)
- AI 응답 분기(`NOT_DEV_TERM`, `POSSIBLE_TYPO`) 처리
- 새 Service 추가 시 Protocol 추상화 필수
- 검색 실패 시 SearchHistory 저장 금지

---

## Agent: data

**담당 파일**
- `DevEtym/DevEtym/Models/Term.swift`
- `DevEtym/DevEtym/Models/TermEntry.swift`
- `DevEtym/DevEtym/Models/SearchHistory.swift`
- `DevEtym/DevEtym/Models/TermResult.swift`
- `DevEtym/DevEtym/Models/AIErrorResponse.swift`
- `DevEtym/DevEtym/Services/BundleDBService.swift`
- `DevEtym/DevEtym/Resources/terms.json`
- `Scripts/generate_db.py`
- `DevEtym/DevEtymTests/BundleDBServiceTests.swift`
- `DevEtym/DevEtymTests/Mocks/MockBundleDBService.swift`

**범위**
- 데이터 모델 스키마 (필드 추가/변경 시 마이그레이션 고려)
- 번들 DB 컨텐츠 (terms.json 생성·확장)
- 번들 DB 검색/자동완성 (`BundleDBService`)
- 카테고리 값 집합 관리 (현재 6개: 동시성·자료구조·네트워크·DB·패턴·기타)

**규칙**
- `keyword`: 영문 소문자만 (공백·특수문자 금지, 하이픈·언더스코어만 허용)
- `aliases`: 최소 1개 (한글 표기 포함 권장)
- 스키마 변경 시 `Term`/`TermEntry`/`BundleDBService`/`ClaudeAPIService` 프롬프트/`generate_db.py` 검증까지 일괄 반영

---

## Agent: ui

**담당 파일**
- `DevEtym/DevEtym/Features/Search/**`
- `DevEtym/DevEtym/Features/Detail/**`
- `DevEtym/DevEtym/Features/Bookmark/**`
- `DevEtym/DevEtym/Features/History/**`
- `DevEtym/DevEtym/Features/Onboarding/**`
- `DevEtym/DevEtym/App/ContentView.swift`
- `DevEtym/DevEtym/Resources/Assets.xcassets/` (컬러 팔레트, AppIcon.appiconset)
- `DevEtym/DevEtym/Resources/Fonts/` (DM Sans·Mono·Serif Display, OFL)
- `DevEtym/DevEtym/Info.plist` (UIAppFonts)
- `DevEtym/DevEtymTests/Mocks/MockTermService.swift`

**범위**
- View·ViewModel (MVVM)
- 디자인 시스템 적용 (컬러, 폰트, 간격, 반경, 뱃지 스타일)
- 네비게이션 (`NavigationStack` + `.navigationDestination(for:)`)
- 상태 동기화 (`.onAppear` 재조회)
- 접근성 (`accessibilityLabel`, Dynamic Type)
- 앱 아이콘 적용 (SVG → PNG 익스포트, AppIcon.appiconset 등록)

**규칙**
- ViewModel은 `TermServiceProtocol`에만 의존, `@MainActor` 선언
- `@Query` 금지
- 모든 View에 `#Preview` 포함 (Preview에서는 `MockTermService` 사용)
- 검색 Task는 `currentSearchTask?.cancel()` 패턴으로 레이스 방지
- `.possibleTypo` 추천 재검색은 push 아닌 replace (`path.removeLast()` 후 append)

디자인 시스템 상세: spec.md Phase 3-0-1·4-4, `docs/wireframe-v2.html`, `docs/icon/icon_candidate_v2.html`.

---

## Agent: settings

**담당 파일**
- `DevEtym/DevEtym/Features/Settings/SettingsView.swift`
- `DevEtym/DevEtym/App/ContentView.swift` (탭 등록, `.preferredColorScheme` 바인딩)

**범위**
- 외관 모드 전환 (`@AppStorage("appearanceMode")`)
- 앱 정보 (버전, 빌드)
- 지원 링크 (mailto, `requestReview`)
- 법적 고지 (OFL 라이선스, AI 생성 고지, 개인정보 처리방침)

**규칙**
- ViewModel 없음 (순수 UI + 시스템 API)
- 기존 Theme(컬러·폰트) 재사용

상세: spec.md Phase 3-8.

---

## Agent: ai

**담당 파일**
- `DevEtym/DevEtym/Services/ClaudeAPIService.swift` (system prompt, request body, tool_use·thinking 활용)
- `DevEtym/DevEtymTests/ClaudeAPIServiceTests.swift` (프롬프트·구조화 응답 관련)
- `DevEtym/DevEtym/Utils/Constants.swift` (모델 ID 변경 시)
- (필요 시) `Scripts/generate_db.py` — 번들 DB 생성 프롬프트 일관성 유지

**범위**
- 프롬프트 엔지니어링 (few-shot 예시, 품질 기준, 톤·길이 가이드)
- Anthropic API 기능 도입 (tool_use, extended thinking, prompt caching)
- 응답 품질 향상 (환각 감소, 일관성, 구조화)

**services 에이전트와의 경계**
- 프롬프트·API 기능 활용 = ai
- HTTP 계층·에러 타입 시그니처 = services
- 경계에 걸치는 리팩터(예: tool_use 도입으로 파싱 단순화)는 ai가 주도하되 Protocol/에러 타입은 유지

**규칙**
- `ClaudeAPIError` 타입·케이스 변경 금지 (services 계약)
- `TermEntry` 스키마 변경 금지 (data 계약)
- 모델 변경 시 `Constants.claudeModel`만 수정, 호출부는 유지

---

## 과거 브랜치 → 에이전트 매핑

| 과거 브랜치 | 새 에이전트 |
|---|---|
| `feat/services` | services |
| `feat/bundle-db` | data |
| `feat/data-extension-and-wiring` | data (+ services: xcconfig 배선) |
| `feat/ui` | ui |
| `feat/ui-design-and-a11y` | ui |
| `feat/settings` | settings |

상세 작업 지시서는 git history 참조(이 커밋 이전의 AGENTS.md).

---

## 미완 작업 / Backlog

### data — 기존 200개 품질 재생성 (옵션 C 잔여 + 옵션 A)

번들 DB 확장(`feat/bundle-db-expansion`, PR #12)에서 신규 300개는 개선된 프롬프트로 생성했으나, 기존 200개는 구 프롬프트 결과가 그대로 남아있음. 전체 일관성을 위해 기존분도 재생성 고려.

**중단 사유:** Anthropic API 크레딧 소진 (2026-04-21). 충전 후 재개.

**절차:**
1. 기존 200개 중 10~15개 샘플을 뽑아 재생성 → before/after 비교 (~$0.20)
2. 개선 체감되면 전체 200개 재생성 (~$2)
3. 미미하면 스킵하고 현 상태 유지

샘플 후보: `deadlock`, `binary-tree`, `tcp`, `crud`, `singleton`, `debug`, `hash`, `cursor`, `decorator`, `kernel` (few-shot 예시인 mutex/jpa/daemon은 공정 비교 불가라 제외).

### analytics — 검색 키워드 수집 (services → settings 순차)

출시 후 실제로 어떤 용어가 검색되는지 파악하여 번들 DB 확장 우선순위에 반영.

**확정 사항 (2026-04-21):**
- **백엔드**: Firebase Analytics (SDK는 Swift Package Manager로 추가)
- **수집 범위**: 검색 키워드, 시각, 결과 종류(번들/AI/notDevTerm/possibleTypo), 오류 종류, Firebase App Instance ID(익명)
- **옵트인 전략**: 첫 실행 시 다이얼로그로 명시 동의 — 한국 PIPA 준수
- **개인정보 처리방침 초안**: `docs/privacy-policy.md`

**services 담당 (선행 — `feat/analytics-infra`)**
- `DevEtym/DevEtym/Services/AnalyticsService.swift` (신규) + `AnalyticsServiceProtocol.swift` — `@MainActor` 준수
- `DevEtym/DevEtym/App/DevEtymApp.swift` — `FirebaseApp.configure()` 호출, EnvironmentKey 주입
- `DevEtym/DevEtym/Services/TermService.swift` — `fetch()` 결과별 트래킹 이벤트 송신
- `DevEtym/DevEtym/Utils/EnvironmentKeys.swift` — AnalyticsService 주입 키 추가
- `DevEtym/DevEtym/Utils/Constants.swift` — 동의 `UserDefaults` 키 상수(예: `analyticsConsentKey`)
- `DevEtym/DevEtymTests/AnalyticsServiceTests.swift` + `Mocks/MockAnalyticsService.swift`
- Xcode Package Dependencies에 `firebase-ios-sdk` 추가 (수동 GUI 작업, 에이전트 대신 사용자 수행)

**settings 담당 (후속 — `feat/analytics-consent-ui`)**
- `DevEtym/DevEtym/Features/Onboarding/OnboardingView.swift` — 첫 실행 시 "데이터 수집 동의" 화면 추가 (기존 온보딩에 이어서)
- `DevEtym/DevEtym/Features/Settings/SettingsView.swift` — "데이터 수집" 섹션 (토글 + "내 식별자 보기" 링크 + "처리방침" 링크)
- 처리방침 텍스트를 앱 내에서 표시할지 외부 URL로 링크할지 결정 (배포 전 GitHub Pages 등에 호스팅하는 방향 권장)

**사용자 수동 전제 조건 (에이전트가 못 하는 부분)**
- Firebase Console에서 iOS 앱 등록 → `GoogleService-Info.plist` 다운로드 → Xcode 프로젝트에 추가
- Xcode에서 `firebase-ios-sdk` Swift Package 추가 (File → Add Package Dependencies)
- `docs/privacy-policy.md` 내용을 최종 URL에 호스팅 (GitHub Pages, Notion, 자체 사이트 등)

**머지 순서**
1. services 에이전트 작업 → PR → main 머지
2. 사용자 수동 작업 (Firebase 콘솔, Xcode 패키지)
3. settings 에이전트 작업 → PR → main 머지

---

## 머지 전 확인

- [ ] 빌드 통과
- [ ] 단위 테스트 통과
- [ ] DevEtymApp.swift의 `.environment(\.termService, ...)` DI 유지
- [ ] 타입 중복 선언 없음 (다른 파일명이면 git 충돌 미감지)
- [ ] `Config.xcconfig`가 커밋되지 않음
- [ ] Preview에서만 MockTermService, 실제 앱에서는 TermService 사용
