# CLAUDE.md — 개발 어원 사전 (DevEtym)

## 프로젝트 개요

개발 용어의 어원과 작명 이유를 한국어로 설명하는 iOS 사전 앱
- 앱 표시 이름: 개발 어원 사전
- 번들 ID: com.robin.devetym
- 플랫폼: iOS 18+, SwiftUI
- 최소 배포 타겟: iOS 18.0

## 기술 스택

- UI: SwiftUI
- 데이터: SwiftData (#Unique, #Index 매크로 사용 — iOS 18+ 필수)
- AI 연동: Claude API (Anthropic), URLSession
- 번들 DB: Resources/terms.json
- 테스트: XCTest + Swift Testing

## 프로젝트 구조

```
DevEtym/
├── App/
│   ├── DevEtymApp.swift        # @main, ModelContainer 설정
│   └── ContentView.swift
├── Features/
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   └── DetailViewModel.swift
│   ├── Bookmark/
│   │   ├── BookmarkView.swift
│   │   └── BookmarkViewModel.swift
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── HistoryViewModel.swift
│   └── Onboarding/
│       └── OnboardingView.swift
├── Models/
│   ├── Term.swift              # SwiftData @Model (캐시 + 북마크, aliases 포함)
│   ├── TermEntry.swift         # 번들 DB + AI 응답 공통 DTO
│   ├── TermResult.swift        # 검색 결과 열거형
│   ├── AIErrorResponse.swift   # AI 오류 응답 모델
│   └── SearchHistory.swift     # SwiftData @Model
├── Services/
│   ├── TermService.swift       # 오케스트레이터 (DB → 캐시 → AI, 북마크, 히스토리 포함)
│   ├── BundleDBService.swift   # 번들 JSON 검색 (keyword + aliases)
│   └── ClaudeAPIService.swift  # Claude API 호출
├── Utils/
│   ├── Constants.swift         # 제보 이메일 등 상수
│   └── EnvironmentKeys.swift   # TermServiceProtocol 환경 주입 키
├── Resources/
│   └── terms.json
├── Scripts/
│   └── generate_db.py          # 번들 DB 배치 생성 스크립트 (Python)
└── Tests/
    ├── TermServiceTests.swift
    ├── BundleDBServiceTests.swift
    ├── ClaudeAPIServiceTests.swift
    └── Mocks/
        ├── MockBundleDBService.swift
        ├── MockClaudeAPIService.swift
        └── MockTermService.swift
```

## 핵심 데이터 흐름

```
[View] ← [ViewModel] ← [TermServiceProtocol]
                            ├─ BundleDBService (terms.json, 메모리)
                            ├─ SwiftData (Term, SearchHistory — 디스크)
                            └─ ClaudeAPIService (네트워크)
```

### 의존성 규칙 (예외 없음)
- **ViewModel → TermServiceProtocol에만 의존**
- ViewModel은 BundleDBService, ClaudeAPIService, modelContext를 직접 참조하지 않음
- 검색, 자동완성, 북마크, 히스토리 모두 TermServiceProtocol을 통해 호출
- SwiftData @Query를 View/ViewModel에서 직접 사용하지 않음
- TermService가 modelContext를 소유하고 모든 SwiftData 조작을 담당

### @MainActor 규칙
- TermServiceProtocol과 TermService는 반드시 `@MainActor`로 선언
- SwiftData의 mainContext는 메인 스레드 전용이므로, async 작업(AI API 호출) 후 modelContext 접근 시 @MainActor가 없으면 크래시 발생
- ViewModel도 @MainActor로 선언 (SwiftUI 표준 관행)

### DI 방식 (EnvironmentKey 패턴)
- SwiftUI `.environment()`에 프로토콜 타입을 직접 전달하면 컴파일 오류 발생
- 반드시 커스텀 EnvironmentKey를 정의하여 프로토콜 주입 (Utils/EnvironmentKeys.swift)
- ViewModel은 `@Environment(\.termService)`로 수신
- 테스트/Preview 시 MockTermService로 교체

### UI 상태 동기화 규칙 (@Query 미사용에 따른 수동 갱신)
- @Query를 사용하지 않으므로 SwiftData 변경이 자동 반영되지 않음
- 데이터 변경 액션(북마크 토글, 히스토리 삭제 등) 직후 ViewModel이 조회 메서드를 다시 호출하여 배열 갱신
- 모든 목록 View(Bookmark, History)는 `.onAppear`에서도 데이터 최신화

### TermServiceProtocol 전체 인터페이스

```swift
@MainActor
protocol TermServiceProtocol {
    // 검색
    func fetch(keyword: String) async throws -> TermResult
    func autocomplete(prefix: String) -> [TermEntry]
    // 북마크
    func toggleBookmark(for entry: TermEntry) throws -> Bool
    func bookmarkedTerms() -> [Term]
    // 히스토리
    func recentSearches(limit: Int) -> [SearchHistory]
    func deleteSearchHistory(_ keyword: String) throws
    func clearAllSearchHistory() throws
}
```

### SwiftData 저장 시점 (lazy 전략)
- AI 응답 수신 시 → Term으로 저장 (source: "ai", aliases 포함)
- 북마크 시 → 번들 용어도 이 시점에 Term으로 저장 (source: "bundle", aliases 포함)
- 번들 DB 용어는 검색만으로는 SwiftData에 저장하지 않음
- SearchHistory는 검색 성공(.found) 시에만 저장

### SwiftData upsert 정책
- 동일 keyword의 Term이 이미 존재하면 새로 생성하지 않음
- AI 응답으로 갱신 시 기존 Term 필드 업데이트 (isBookmarked, source 보존)
- SearchHistory는 동일 keyword 존재 시 searchedAt만 갱신 (insert 아닌 upsert)

### TermEntry ↔ Term 변환 규칙
- 변환 시 aliases를 반드시 포함할 것 (데이터 소실 방지)
- keyword, aliases, summary, etymology, namingReason 모두 보존
- Term.init(from:source:isBookmarked:) 편의 이니셜라이저 사용
- Term.toEntry() 역변환 메서드 사용

### 검색 결과 분기 (TermResult)
- `.found(TermEntry)` → 정상 결과 표시
- `.notDevTerm` → "개발 용어를 검색해주세요" 안내
- `.possibleTypo(String)` → "{suggestion}을(를) 찾으셨나요?" 안내

### 네비게이션
- NavigationStack + .navigationDestination(for:) 패턴 사용
- possibleTypo 추천 용어 탭 시 → 같은 DetailView를 replace (push 아닌 replace)

## 코딩 규칙

- 언어: Swift 5.9+, async/await 사용
- 아키텍처: MVVM. View는 UI만, 로직은 ViewModel
- SwiftData: @Model 클래스에 비즈니스 로직 넣지 말 것
- 동시성: TermService, TermServiceProtocol, 모든 ViewModel은 @MainActor 선언 필수
- 에러 처리: 모든 throws 함수는 호출부에서 do-catch 처리
- 주석: 한국어로 작성
- 네이밍: 변수/함수는 camelCase, 타입은 PascalCase
- Preview: 모든 View에 #Preview 매크로 포함
- 새 Service 작성 시 Protocol 추상화 필수
- 다크모드: 시스템 설정 자동 대응 (커스텀 컬러 사용 시 Color asset 또는 .init(light:dark:))

## 절대 하지 말 것

- Force unwrap (!) 사용 금지 — guard let 또는 if let 사용
- Main thread 외에서 UI 업데이트 금지
- API 키를 코드에 하드코딩 금지 — Info.plist 또는 환경변수 사용
- 거대한 단일 파일 — 역할별로 파일 분리
- 검색 실패 시 SearchHistory 저장 금지
- ViewModel에서 BundleDBService / ClaudeAPIService / modelContext 직접 참조 금지
- View/ViewModel에서 SwiftData @Query 직접 사용 금지 — TermServiceProtocol을 통할 것
- TermEntry → Term 변환 시 aliases 누락 금지
- TermService/TermServiceProtocol에서 @MainActor 누락 금지

## 커밋 규칙

Conventional Commits 형식 사용:
- feat: 새 기능
- fix: 버그 수정
- refactor: 리팩토링
- test: 테스트 추가/수정
- chore: 빌드/설정 변경

예시: `feat: add alias matching to BundleDBService`

## 테스트 규칙

- 새 Service 클래스 작성 시 반드시 대응하는 테스트 파일 생성
- Mock 객체는 Tests/Mocks/ 폴더에 위치
- 테스트 함수명: test_[대상]_[조건]_[기대결과] 형식
- AI 오류 응답(NOT_DEV_TERM, POSSIBLE_TYPO) 분기도 테스트 필수
- 북마크 토글, 히스토리 CRUD 테스트 필수
