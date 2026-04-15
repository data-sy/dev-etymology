# spec.md — DevEtym 구현 명세서 (Claude Code 전용)

> 이 문서는 Claude Code가 참조하는 구현 명세입니다
> Xcode 프로젝트 설정, 인프라, 배포 등 인간 작업은 CHECKLIST.md를 참조하세요
> CLAUDE.md의 코딩 규칙을 반드시 준수하세요

---

## Phase 1 — 모델 및 기반 코드

### 1-1. SwiftData 모델 정의

**Models/Term.swift** — AI 캐시 및 북마크용
```swift
@Model
class Term {
    #Unique<Term>([\.keyword])
    #Index<Term>([\.isBookmarked], [\.createdAt])

    var keyword: String        // 정규화된 용어 (영문 소문자)
    var aliases: [String]      // 대체 표기 (한글, 풀네임 등)
    var summary: String        // 한 줄 요약
    var etymology: String      // 어원 설명
    var namingReason: String   // 작명 이유
    var source: String         // "bundle" | "ai"
    var isBookmarked: Bool
    var createdAt: Date

    init(keyword: String, aliases: [String] = [],
         summary: String, etymology: String, namingReason: String,
         source: String = "ai",
         isBookmarked: Bool = false) {
        self.keyword = keyword
        self.aliases = aliases
        self.summary = summary
        self.etymology = etymology
        self.namingReason = namingReason
        self.source = source
        self.isBookmarked = isBookmarked
        self.createdAt = .now
    }
}

// MARK: - TermEntry 변환

extension Term {
    /// TermEntry → Term 변환 (aliases 보존 필수)
    convenience init(from entry: TermEntry, source: String, isBookmarked: Bool = false) {
        self.init(
            keyword: entry.keyword.lowercased(),
            aliases: entry.aliases,
            summary: entry.summary,
            etymology: entry.etymology,
            namingReason: entry.namingReason,
            source: source,
            isBookmarked: isBookmarked
        )
    }

    /// Term → TermEntry 역변환
    func toEntry() -> TermEntry {
        TermEntry(
            keyword: keyword,
            aliases: aliases,
            summary: summary,
            etymology: etymology,
            namingReason: namingReason
        )
    }
}
```

**Models/SearchHistory.swift**
```swift
@Model
class SearchHistory {
    #Unique<SearchHistory>([\.keyword])
    #Index<SearchHistory>([\.searchedAt])

    var keyword: String
    var searchedAt: Date

    init(keyword: String) {
        self.keyword = keyword
        self.searchedAt = .now
    }
}
```

### 1-2. DTO 및 열거형

**Models/TermEntry.swift** — 번들 DB + AI 응답 공통 DTO
```swift
struct TermEntry: Codable {
    let keyword: String
    let aliases: [String]
    let summary: String
    let etymology: String
    let namingReason: String
}
```

> **TermEntry ↔ Term 변환 시 aliases를 반드시 포함할 것**
> 변환은 Term.init(from:source:isBookmarked:)와 Term.toEntry()만 사용

**Models/TermResult.swift** — 검색 결과 분기
```swift
enum TermResult {
    case found(TermEntry)
    case notDevTerm
    case possibleTypo(String)
}
```

**Models/AIErrorResponse.swift** — AI 오류 응답
```swift
struct AIErrorResponse: Codable {
    let error: String          // "NOT_DEV_TERM" | "POSSIBLE_TYPO"
    let suggestion: String?
}
```

### 1-3. 상수 정의

**Utils/Constants.swift**
```swift
enum Constants {
    static let reportEmail = "devetym@gmail.com"
    // Anthropic API 공식 모델 ID — 변경 시 https://docs.anthropic.com 확인
    static let claudeModel = "claude-sonnet-4-5-20250514"
    static let apiTimeout: TimeInterval = 30
    static let autocompleteDebounceMs: Int = 300
    static let recentSearchLimit: Int = 5
}
```

### 1-4. EnvironmentKey 정의

**Utils/EnvironmentKeys.swift**
```swift
import SwiftUI

/// SwiftUI .environment()에 프로토콜 타입을 직접 전달하면 컴파일 오류 발생
/// 반드시 커스텀 EnvironmentKey를 통해 TermServiceProtocol을 주입
private struct TermServiceKey: EnvironmentKey {
    static let defaultValue: any TermServiceProtocol = PlaceholderTermService()
}

extension EnvironmentValues {
    var termService: any TermServiceProtocol {
        get { self[TermServiceKey.self] }
        set { self[TermServiceKey.self] = newValue }
    }
}

/// 기본값용 더미 — 실제 사용 시 반드시 DevEtymApp에서 실제 TermService로 교체
/// Preview에서는 MockTermService로 교체
@MainActor
private class PlaceholderTermService: TermServiceProtocol {
    func fetch(keyword: String) async throws -> TermResult { .notDevTerm }
    func autocomplete(prefix: String) -> [TermEntry] { [] }
    func toggleBookmark(for entry: TermEntry) throws -> Bool { false }
    func bookmarkedTerms() -> [Term] { [] }
    func recentSearches(limit: Int) -> [SearchHistory] { [] }
    func deleteSearchHistory(_ keyword: String) throws {}
    func clearAllSearchHistory() throws {}
}
```

### 1-5. 초기 번들 DB

**Resources/terms.json** — 초기 20개 용어로 시작 (Phase 4에서 200개로 확장)
```json
[
  {
    "keyword": "mutex",
    "aliases": ["뮤텍스", "mutual exclusion"],
    "summary": "동시 접근을 막는 잠금 장치",
    "etymology": "라틴어 mutuus(상호의) + exclusio(배제) → Mutual Exclusion의 줄임말",
    "namingReason": "두 스레드가 동시에 같은 자원에 접근하지 못하도록 서로(mutual) 차단(exclusion)하는 개념에서 유래"
  }
]
```
스키마: keyword(필수), aliases(필수, 최소 1개), summary, etymology, namingReason

### 1-6. 앱 진입점

**App/DevEtymApp.swift**
```swift
@main
struct DevEtymApp: App {
    let termService: TermService

    init() {
        let container = try! ModelContainer(for: Term.self, SearchHistory.self)
        self.termService = TermService(modelContext: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.termService, termService)
        }
    }
}
```

> `.environment(\.termService, ...)` — EnvironmentKey 기반 주입
> ViewModel은 `@Environment(\.termService) var termService`로 수신

✅ Phase 1 완료 조건: 모든 모델 파일 + EnvironmentKeys + DevEtymApp 컴파일 오류 없음

---

## Phase 2 — 서비스 레이어

### 2-1. BundleDBService

**Services/BundleDBService.swift**

```swift
protocol BundleDBServiceProtocol {
    func search(keyword: String) -> TermEntry?
    func autocomplete(prefix: String) -> [TermEntry]
}
```

- terms.json을 앱 시작 시 1회 로드, 메모리 캐시
- search: keyword + aliases 대소문자 무시 완전 매칭
- autocomplete: keyword prefix 매칭 (타이핑 중 자동완성용)

```swift
func search(keyword: String) -> TermEntry? {
    let normalized = keyword
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    return terms.first { entry in
        entry.keyword.lowercased() == normalized ||
        entry.aliases.contains(where: { $0.lowercased() == normalized })
    }
}

func autocomplete(prefix: String) -> [TermEntry] {
    let normalized = prefix.lowercased()
    guard !normalized.isEmpty else { return [] }
    return terms.filter { $0.keyword.lowercased().hasPrefix(normalized) }
}
```

### 2-2. ClaudeAPIService

**Services/ClaudeAPIService.swift**

```swift
protocol ClaudeAPIServiceProtocol {
    func generate(keyword: String) async throws -> TermEntry
}
```

- 엔드포인트: POST https://api.anthropic.com/v1/messages
- 모델: Constants.claudeModel
- API 키: Info.plist의 CLAUDE_API_KEY (Bundle.main에서 읽기)
- 타임아웃: Constants.apiTimeout

**API 키 검증:**
- Bundle.main에서 CLAUDE_API_KEY 읽기 실패 또는 빈 문자열 → .invalidAPIKey throw
- 이 검증은 generate() 호출 시 매번 수행

**에러 타입:**
```swift
enum ClaudeAPIError: Error {
    case invalidAPIKey
    case timeout
    case networkError(Error)
    case invalidResponse
    case notDevTerm
    case possibleTypo(suggestion: String)
}
```

**시스템 프롬프트:**
```
당신은 개발 용어의 어원을 설명하는 사전 데이터 제공자입니다
반드시 아래의 엄격한 JSON 형식으로만 응답해야 하며, 그 외의 어떤 텍스트나 마크다운(```)도 포함해서는 안 됩니다

[개발 용어인 경우의 응답 구조]
{
  "keyword": "mutex",
  "aliases": ["뮤텍스", "mutual exclusion"],
  "summary": "동시 접근을 막는 잠금 장치",
  "etymology": "라틴어 mutuus(상호의) + exclusio(배제)",
  "namingReason": "두 스레드가 동시에 접근하지 못하도록..."
}

[개발 용어가 아닌 경우의 응답 구조]
{"error": "NOT_DEV_TERM", "suggestion": null}

[개발 용어는 아니지만 오타로 추정되는 경우의 응답 구조]
{"error": "POSSIBLE_TYPO", "suggestion": "올바른 용어"}

[엄격한 출력 제한]
응답의 첫 글자는 반드시 '{'로 시작하고, 마지막 글자는 '}'로 끝나야 합니다
어떠한 경우에도 마크다운 백틱(```)이나 부연 설명을 텍스트에 포함하지 마세요

[주의사항]
- 어원이 불확실한 경우 "정확한 어원은 불분명하나"로 시작하여 알려진 설만 서술하세요
- 추측이나 민간어원(folk etymology)을 사실처럼 서술하지 마세요
- 약어의 경우 반드시 각 글자가 무엇의 약자인지 명시하세요
```

**응답 파싱 로직:**
1. content[0].text에서 앞뒤 공백 제거
2. ```json ... ``` 또는 ``` ... ``` 마크다운 블록 감싸기가 있으면 정규식으로 제거 (프롬프트로 금지했으나 방어적 전처리)
3. 결과 문자열로 JSON 디코딩 시도
4. "error" 키 존재 → AIErrorResponse로 디코딩
   - NOT_DEV_TERM → throw ClaudeAPIError.notDevTerm
   - POSSIBLE_TYPO → throw ClaudeAPIError.possibleTypo(suggestion:)
5. "error" 키 없음 → TermEntry로 디코딩
6. 디코딩 실패 → throw ClaudeAPIError.invalidResponse

### 2-3. TermService (오케스트레이터)

**Services/TermService.swift**

> **@MainActor 필수**: SwiftData mainContext는 메인 스레드 전용
> async 작업(AI API 호출) 후 modelContext 접근 시 @MainActor가 없으면 크래시

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

@MainActor
class TermService: TermServiceProtocol {
    private let modelContext: ModelContext
    private let bundleDBService: BundleDBServiceProtocol
    private let claudeAPIService: ClaudeAPIServiceProtocol

    init(modelContext: ModelContext,
         bundleDBService: BundleDBServiceProtocol = BundleDBService(),
         claudeAPIService: ClaudeAPIServiceProtocol = ClaudeAPIService()) {
        self.modelContext = modelContext
        self.bundleDBService = bundleDBService
        self.claudeAPIService = claudeAPIService
    }
}
```

> **모든 ViewModel은 이 프로토콜에만 의존한다**
> 검색, 자동완성, 북마크, 히스토리 CRUD 모두 이 프로토콜을 통해 호출
> ViewModel은 modelContext, BundleDBService, ClaudeAPIService를 직접 참조하지 않음

**입력 정규화:**
```swift
private func normalize(_ input: String) -> String {
    input
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}
```

**autocomplete 구현:**
```swift
func autocomplete(prefix: String) -> [TermEntry] {
    bundleDBService.autocomplete(prefix: prefix)
}
```

**fetch 오케스트레이션 순서:**
1. 입력 정규화
2. 정규화 결과가 빈 문자열이면 즉시 `.notDevTerm` 반환 (API 호출 안 함)
3. BundleDBService.search(keyword) → 히트 시 `.found` 반환 + 히스토리 upsert
4. SwiftData에서 Term 조회 (keyword 매칭) → 히트 시 `.found` 반환 + 히스토리 upsert
5. ClaudeAPIService.generate(keyword) 호출
   - 성공 → SwiftData에 Term upsert (source: "ai", aliases 포함) + 히스토리 upsert + `.found` 반환
   - .notDevTerm → `.notDevTerm` 반환 (히스토리 저장 안 함)
   - .possibleTypo → `.possibleTypo(suggestion)` 반환 (히스토리 저장 안 함)
   - 기타 에러 → throw (히스토리 저장 안 함)

**SwiftData upsert 정책:**
- Term upsert: 동일 keyword 존재 시 필드 업데이트 (isBookmarked, source 보존), 없으면 insert
- SearchHistory upsert: 동일 keyword 존재 시 searchedAt만 갱신, 없으면 insert

**북마크 토글 (toggleBookmark):**
```
toggleBookmark(for entry) →
  SwiftData에 Term 존재? → isBookmarked 토글, 변경된 값 반환
  미존재 (번들 용어)? → Term(from: entry, source: "bundle", isBookmarked: true) 저장, true 반환
```

**bookmarkedTerms:**
- SwiftData에서 isBookmarked == true인 Term 목록 반환
- createdAt 내림차순 정렬

**히스토리 메서드:**
- recentSearches(limit:) → searchedAt 내림차순, 상위 limit개 반환
- deleteSearchHistory(keyword:) → 해당 keyword의 SearchHistory 삭제
- clearAllSearchHistory() → 모든 SearchHistory 삭제

### 2-4. 테스트

**Tests/TermServiceTests.swift**
- test_fetch_emptyInput_returnsNotDevTerm
- test_fetch_bundleHit_returnsImmediately
- test_fetch_bundleAlias_returnsCorrectTerm
- test_fetch_bundleMiss_callsClaudeAPI
- test_fetch_cachedResult_skipsAPI
- test_fetch_apiError_throwsError
- test_fetch_notDevTerm_returnsNotDevTerm
- test_fetch_possibleTypo_returnsSuggestion
- test_fetch_success_savesHistory
- test_fetch_failure_doesNotSaveHistory
- test_fetch_existingTerm_updatesFieldsPreservesBookmark
- test_autocomplete_delegatesToBundleDB
- test_toggleBookmark_existingTerm_togglesValue
- test_toggleBookmark_bundleTerm_createsTerm
- test_bookmarkedTerms_returnsOnlyBookmarked
- test_recentSearches_returnsInOrder
- test_deleteSearchHistory_removesEntry
- test_clearAllSearchHistory_removesAll

**Tests/BundleDBServiceTests.swift**
- test_search_exactKeyword_returnsEntry
- test_search_alias_returnsEntry
- test_search_caseInsensitive_returnsEntry
- test_search_notFound_returnsNil
- test_autocomplete_prefix_returnsMatches
- test_autocomplete_empty_returnsEmpty

**Tests/ClaudeAPIServiceTests.swift**
- test_generate_validTerm_returnsTermEntry
- test_generate_notDevTerm_throwsNotDevTerm
- test_generate_possibleTypo_throwsWithSuggestion
- test_generate_timeout_throwsTimeout
- test_generate_invalidJSON_throwsInvalidResponse
- test_generate_markdownWrappedJSON_parsesCorrectly
- test_generate_missingAPIKey_throwsInvalidAPIKey

✅ Phase 2 완료 조건: 모든 테스트 통과, Mock으로 API 호출 검증

---

## Phase 3 — UI 구현

### 3-0. 공통 규칙

> **모든 ViewModel은 TermServiceProtocol에만 의존한다**
> `@Environment(\.termService)`로 주입받아 사용
> modelContext, BundleDBService, ClaudeAPIService 직접 참조 금지
> SwiftData @Query 직접 사용 금지
> 모든 ViewModel은 @MainActor로 선언

> **상태 동기화**: @Query를 사용하지 않으므로 데이터 변경 시 자동 반영되지 않음
> 북마크 토글, 히스토리 삭제 등 변경 액션 직후 ViewModel이 조회 메서드를 다시 호출하여 배열 갱신
> 모든 목록 View(Bookmark, History)는 `.onAppear`에서도 데이터 최신화

**네비게이션:** NavigationStack + .navigationDestination(for:) 패턴
**다크모드:** 시스템 설정 자동 대응, 커스텀 컬러는 Color asset 사용

### 3-1. 탭바 구조

**App/ContentView.swift**
```swift
TabView {
    SearchView()
        .tabItem { Label("검색", systemImage: "magnifyingglass") }
    BookmarkView()
        .tabItem { Label("북마크", systemImage: "bookmark") }
    HistoryView()
        .tabItem { Label("히스토리", systemImage: "clock") }
}
```

### 3-2. SearchView + SearchViewModel

**네비게이션 상태 관리:**
- SearchView가 `@State private var path = NavigationPath()`를 소유
- NavigationStack(path: $path)으로 바인딩
- DetailView push: `path.append(keyword)`
- possibleTypo 재검색 시: `path.removeLast()` 후 새 keyword `path.append(suggestion)`

**검색 Task 관리:**
- SearchViewModel은 `private var currentSearchTask: Task<Void, Never>?` 프로퍼티를 보유
- 새로운 검색 시작 시 기존 Task를 `currentSearchTask?.cancel()`로 취소 후 새 Task 할당
- 연타/빠른 재검색 시 레이스 컨디션 방지

**상태:**
- 검색어 입력 → 엔터/검색 버튼 → DetailView push
- 검색창 하단 안내 문구: "영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)"
- 타이핑 중 자동완성: termService.autocomplete(prefix:) → 드롭다운 리스트
  - 디바운싱: 300ms (Task.sleep 또는 Combine debounce)
  - 최소 입력 길이: 1자 이상
- 최근 검색 칩: termService.recentSearches(limit: 5) 호출
- 칩 탭 → 해당 용어로 DetailView push
- `.onAppear`에서 최근 검색 목록 갱신

### 3-3. DetailView + DetailViewModel

**검색 Task 관리:**
- DetailViewModel도 `currentSearchTask`를 보유하여 fetch 중복 호출 방지
- View가 사라질 때(onDisappear) 진행 중인 Task 취소

**TermResult별 표시:**

`.found(TermEntry)`:
- 용어명 (large title)
- 한 줄 요약
- 어원 블록 (좌측 accent 보더)
- 작명 이유 본문 — **ScrollView로 감싸서 긴 텍스트 대응**
- 북마크 버튼 (toolbar) → termService.toggleBookmark(for:) 호출
- 하단 고정: 오류 제보 버튼

`.notDevTerm`:
- "개발 용어를 검색해주세요" 안내 화면
- 검색으로 돌아가기 버튼

`.possibleTypo(suggestion)`:
- "{suggestion}을(를) 찾으셨나요?" 안내
- 추천 용어 탭 시 → 같은 DetailView를 replace (NavigationStack path 교체)

**로딩 상태:**
- 번들 DB 히트: 로딩 없음
- AI 생성 중: ProgressView + "어원을 분석하는 중..." 텍스트

**에러 처리 (ViewModel에서 catch → 상태 변수로 Alert 표시):**
- TermResult에 에러 케이스를 추가하지 않음 — 에러는 throw → ViewModel catch 패턴 유지
- ViewModel은 `@Published var errorMessage: String?`로 에러 상태 관리
- ClaudeAPIError 타입별 분기:
  - .invalidAPIKey → "API 키 설정이 필요합니다"
  - .timeout → "요청 시간이 초과되었습니다. 다시 시도해주세요"
  - .networkError(let error) → URLError.code로 세분화:
    - .notConnectedToInternet → "인터넷 연결을 확인해주세요"
    - 기타 → "네트워크 연결이 불안정합니다. 다시 시도해주세요"
  - .invalidResponse → "응답을 처리할 수 없습니다. 다시 시도해주세요"
  - 기타 → "오류가 발생했습니다" + 제보 유도
- Alert dismiss 후 검색 화면으로 돌아가기

### 3-4. 오류 제보 (mailto)

**위치:** DetailView 하단 고정

**버튼 텍스트:** "이 설명이 잘못됐나요? 오류 제보하기"

**mailto 구성:**
```
수신: Constants.reportEmail
제목: [오류제보] {keyword}
본문:
■ 용어: {keyword}
■ 출처: {source}
■ 요약: {summary}
■ 어원: {etymology}
■ 작명이유: {namingReason}
─────────────
어떤 부분이 잘못되었나요?
→
```

### 3-5. BookmarkView + BookmarkViewModel

- termService.bookmarkedTerms()로 목록 조회
- `.onAppear`에서 목록 갱신
- 빈 상태: 안내 문구
- 항목 탭 → DetailView push
- 스와이프 삭제 → termService.toggleBookmark(for:) 호출 → **직후 목록 다시 조회**

### 3-6. HistoryView + HistoryViewModel

- termService.recentSearches(limit:)로 목록 조회
- `.onAppear`에서 목록 갱신
- 항목 탭 → DetailView push
- 스와이프 삭제 → termService.deleteSearchHistory(_:) → **직후 목록 다시 조회**
- 상단 "전체 삭제" 버튼 → termService.clearAllSearchHistory() → **직후 목록 다시 조회**

### 3-7. OnboardingView

- 앱 첫 실행 시 1회만 표시 (@AppStorage("hasSeenOnboarding") 플래그)
- 표시 내용:
  - 앱 소개 (1-2문장)
  - "이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 제보해 주세요."
  - 시작하기 버튼

✅ Phase 3 완료 조건: 모든 탭 화면 렌더링, 검색 → 결과 플로우 동작, 에러 Alert 분기 동작, 오류 제보 mailto 동작

---

## Phase 4 — 통합 및 마무리

### 4-1. 오류 처리 UI

> Phase 3-3에서 정의한 에러 분기가 통합 환경에서도 정상 동작하는지 확인
> 네트워크 오류 감지는 URLError.code 기반 (NWPathMonitor 미사용)

### 4-2. 접근성
- 모든 이미지/아이콘에 accessibilityLabel 추가
- Dynamic Type 지원 확인

### 4-3. 번들 DB 확장
- 초기 20개 → Claude API 배치 생성 스크립트로 200개로 확장
- 기존 20개 용어를 반드시 포함 (keyword/aliases 변경 금지)
- 스크립트: Scripts/generate_db.py
- 각 용어에 aliases 포함 필수 (빈 배열 금지, 최소 1개)
- 생성 후 JSON 유효성 + aliases 존재 여부 검증

✅ Phase 4 완료 조건: 모든 Phase 1-3 기능 통합 동작, 오류 처리 완비
