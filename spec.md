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
    #Index<Term>([\.isBookmarked], [\.createdAt], [\.category])

    var keyword: String        // 정규화된 용어 (영문 소문자)
    var aliases: [String]      // 대체 표기 (한글, 풀네임 등)
    var category: String       // 카테고리 (동시성, 자료구조, 네트워크, DB, 패턴, 기타)
    var summary: String        // 한 줄 요약
    var etymology: String      // 어원 설명
    var namingReason: String   // 작명 이유
    var source: String         // "bundle" | "ai"
    var isBookmarked: Bool
    var createdAt: Date

    init(keyword: String, aliases: [String] = [], category: String,
         summary: String, etymology: String, namingReason: String,
         source: String = "ai",
         isBookmarked: Bool = false) {
        self.keyword = keyword
        self.aliases = aliases
        self.category = category
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
    /// TermEntry → Term 변환 (aliases + category 보존 필수)
    convenience init(from entry: TermEntry, source: String, isBookmarked: Bool = false) {
        self.init(
            keyword: entry.keyword.lowercased(),
            aliases: entry.aliases,
            category: entry.category,
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
            category: category,
            summary: summary,
            etymology: etymology,
            namingReason: namingReason
        )
    }
}
```

> **SwiftData 마이그레이션 주의:** 배포 전 개발 단계에서 `category` 필드를 추가할 경우, 기존 SwiftData 저장소와 스키마 불일치가 발생할 수 있음. 개발자는 앱 삭제 후 재설치 또는 시뮬레이터 데이터 리셋으로 대응. 릴리즈 이후 필드를 추가하는 경우엔 `VersionedSchema` + `MigrationPlan` 필요.

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
    let category: String
    let summary: String
    let etymology: String
    let namingReason: String
}
```

> **TermEntry ↔ Term 변환 시 aliases + category를 반드시 포함할 것**
> 변환은 Term.init(from:source:isBookmarked:)와 Term.toEntry()만 사용

**카테고리 값 (번들 DB·AI 응답 공통 고정 집합):**
- `동시성` · `자료구조` · `네트워크` · `DB` · `패턴` · `기타`
- 6개 외의 값을 허용하지 않음 (AI 응답 포함)

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
    static let claudeModel = "claude-sonnet-4-6"
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
    "category": "동시성",
    "summary": "동시 접근을 막는 잠금 장치",
    "etymology": "라틴어 mutuus(상호의) + exclusio(배제) → Mutual Exclusion의 줄임말",
    "namingReason": "두 스레드가 동시에 같은 자원에 접근하지 못하도록 서로(mutual) 차단(exclusion)하는 개념에서 유래"
  }
]
```
스키마: keyword(필수), aliases(필수, 최소 1개), category(필수, 6개 값 중 하나), summary, etymology, namingReason

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
  "category": "동시성",
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

[카테고리 규칙]
- category 필드는 반드시 다음 6개 값 중 하나여야 합니다: "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"
- 6개 분류에 애매하게 걸치는 경우 가장 핵심적인 분류를 선택하세요
- 어느 분류에도 명확히 속하지 않으면 "기타"를 사용하세요

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

### 3-0-1. 디자인 시스템

참고: `devetym-wireframe-v2.html` (레포 루트)

**컬러 팔레트 (다크모드 우선, Asset Catalog에 등록):**
- `bg` = `#0a0a0a` — 앱 배경
- `surface` = `#111111` — 카드/섹션 배경
- `surface2` = `#1a1a1a` — 입력창/검색 박스
- `border` = `#222222` — 구분선
- `accent` = `#c8f060` — 주요 강조(카테고리 태그, CTA, 활성 탭)
- `accent2` = `#60c8f0` — 보조 강조(떠오르는 용어 등, P2)
- `accentAI` = `#f0a060` — AI 생성 뱃지 전용
- `text` = `#f0f0f0` — 본문
- `textDim` = `#999999` — 2차 본문
- `textMuted` = `#666666` — 라벨/캡션

라이트모드 값은 Asset Catalog의 Appearances에서 별도 지정. 이번 버전에선 다크모드만 완성도 있게 맞추고, 라이트모드는 시스템 기본 팔레트로 fallback 허용.

**폰트 (번들에 포함):**
- `DM Sans` (Regular 400, Medium 500, Light 300) — 본문 기본
- `DM Mono` (Regular 400, Medium 500, Light 300) — 코드·라벨·칩·탭라벨
- `DM Serif Display` (Regular + Italic) — 용어명 large title, 섹션 타이틀

Google Fonts에서 OFL 라이선스로 다운로드하여 `Resources/Fonts/`에 포함.
`Info.plist`의 `UIAppFonts` 배열에 파일명 등록.
사용은 `.font(.custom("DMSans-Regular", size: 13, relativeTo: .body))` 패턴으로 Dynamic Type 연계.

**간격/반경 기본값:**
- 기본 패딩: 14–18px
- 카드 radius: 12–14px
- pill radius: 5–20px (뱃지: 5px, 칩: 20px)

**뱃지 스타일:**
- 카테고리 태그: `accent` 컬러 + 8% opacity 배경 + 20% opacity 보더, radius 5px, DM Mono 9px, uppercase
- AI 생성 뱃지: `accentAI` 컬러 동일 구조
- 최근 검색 칩: `surface2` 배경 + border, radius 20px, DM Mono 10px

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
    SettingsView()
        .tabItem { Label("설정", systemImage: "gearshape") }
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
- **카테고리 태그 배지** (accent 컬러 pill — 예: "동시성 · Concurrency")
- **AI 생성 뱃지** (source가 "ai"인 경우에만, 오렌지 계열 accent pill — 예: "✦ AI 생성")
  - 번들 DB 결과의 경우엔 표시하지 않음
  - ViewModel이 DetailView에 TermEntry와 함께 source 값(또는 isAIGenerated Bool)을 전달
- 한 줄 요약
- 어원 블록 (좌측 accent 보더)
- 작명 이유 본문 — **ScrollView로 감싸서 긴 텍스트 대응**
- 액션 행: 북마크 버튼 + **공유 버튼(ShareLink)**
  - 북마크: termService.toggleBookmark(for:) 호출
  - 공유: ShareLink로 `"{keyword}\n\n{summary}\n\n— DevEtym"` 형식 텍스트 공유
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
- **각 항목은 keyword + 한 줄 미리보기(summary 또는 aliases 첫 요소)** 를 함께 표시
- 항목 탭 → DetailView push
- 스와이프 삭제 → termService.toggleBookmark(for:) 호출 → **직후 목록 다시 조회**

### 3-6. HistoryView + HistoryViewModel

- termService.recentSearches(limit:)로 목록 조회
- `.onAppear`에서 목록 갱신
- **각 항목의 `searchedAt`은 상대 시간("방금 전", "1시간 전", "어제", "3일 전")으로 표시**
  - `RelativeDateTimeFormatter`(단위 자동) 사용, 한국어 로케일
- 항목 탭 → DetailView push
- 스와이프 삭제 → termService.deleteSearchHistory(_:) → **직후 목록 다시 조회**
- 상단 "전체 삭제" 버튼 → termService.clearAllSearchHistory() → **직후 목록 다시 조회**

### 3-7. OnboardingView

- 앱 첫 실행 시 1회만 표시 (@AppStorage("hasSeenOnboarding") 플래그)
- 표시 내용:
  - 앱 소개 (1-2문장)
  - "이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 제보해 주세요."
  - 시작하기 버튼

### 3-8. SettingsView

**Features/Settings/SettingsView.swift**

ViewModel 불필요 (로직 없음, 순수 UI + 시스템 API 호출만).

**화면 구성 (List + Section 패턴):**

```
외관
  ├ 화면 모드: 시스템 / 라이트 / 다크 (Picker)

앱 정보
  ├ 앱 버전: Bundle.main 값 표시 (CFBundleShortVersionString)
  ├ 빌드 번호: (CFBundleVersion)

지원
  ├ 개발자에게 문의 → mailto (Constants.reportEmail)
  ├ 앱 평가하기 → StoreKit requestReview 또는 App Store URL
  ├ 오류 제보 → mailto (Constants.reportEmail)

법적 고지
  ├ 오픈소스 라이선스 (DM Fonts — OFL)
  ├ AI 생성 고지: "이 앱의 모든 어원 설명은 AI가 생성합니다"
  ├ 개인정보 처리방침 → 외부 URL (추후 등록)
```

**화면 모드 구현:**
- `@AppStorage("appearanceMode") var appearanceMode: Int = 0`
  - 0: 시스템, 1: 라이트, 2: 다크
- 앱 루트(ContentView 또는 DevEtymApp)에서 `.preferredColorScheme()` 적용
  - 0 → nil (시스템 따라감), 1 → .light, 2 → .dark

**앱 평가하기:**
- iOS 16+: `@Environment(\.requestReview)` 사용
- 또는 App Store URL: `https://apps.apple.com/app/id{APP_ID}?action=write-review`
- 앱 출시 전에는 requestReview만 사용 (URL은 APP_ID 필요)

**#Preview:**
```swift
#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
```

✅ Phase 3 완료 조건: 모든 탭 화면 렌더링, 검색 → 결과 플로우 동작, 에러 Alert 분기 동작, 오류 제보 mailto 동작, 설정 화면에서 외관 전환 동작

---

## Phase 4 — 통합 및 마무리

### 4-1. 오류 처리 UI

> Phase 3-3에서 정의한 에러 분기가 통합 환경에서도 정상 동작하는지 확인
> 네트워크 오류 감지는 URLError.code 기반 (NWPathMonitor 미사용)

### 4-2. 접근성
- 모든 이미지/아이콘에 accessibilityLabel 추가
- Dynamic Type 지원 확인 — `.font(.custom(...))` 사용 시 `relativeTo:` 파라미터로 연계
- 다크/라이트모드 전환 시 전 화면 렌더링 검증

### 4-3. 번들 DB 확장
- 초기 20개 → Claude API 배치 생성 스크립트로 200개로 확장
- 각 용어에 `category` 필드 필수, 값은 6개 고정 집합 중 하나
- 기존 20개 용어를 반드시 포함 (keyword/aliases 변경 금지)
- 스크립트: Scripts/generate_db.py
- 각 용어에 aliases 포함 필수 (빈 배열 금지, 최소 1개)
- 생성 후 JSON 유효성 + aliases 존재 여부 검증

### 4-4. 앱 아이콘 적용

> 디자인 자산: `docs/icon/assets/v2/icon.svg` (v2 최종판)
> 검토 자료: `docs/icon/icon_candidate_v2.html`
> 색상: 딥 그린 `#2E5D3A` / 크림 `#F7E8D0`
> 앱 표시 이름: "개발 어원 사전" (CLAUDE.md 기준) — 아이콘 타이포와 일치

**PNG 익스포트 (single-size 방식)**

v2는 단일 SVG가 1024→28px 모든 사이즈에서 식별 가능하도록 설계되어, 사이즈별 최적화 없이 1024×1024 PNG 하나만 제작하고 Xcode가 자동으로 다운스케일하도록 위임한다.

```bash
rsvg-convert -w 1024 -h 1024 docs/icon/assets/v2/icon.svg \
  -o DevEtym/DevEtym/Assets.xcassets/AppIcon.appiconset/icon.png
```

**Assets.xcassets 등록**

- 경로: `DevEtym/DevEtym/Assets.xcassets/AppIcon.appiconset/`
- `Contents.json` single-size 스키마: `idiom: "universal"`, `platform: "ios"`, `size: "1024x1024"`, `filename: "icon.png"`
- Info.plist의 `CFBundleIcons` 자동 배선 (Xcode가 Asset Catalog 사용 시)

**검증 체크리스트**

- [ ] 시뮬레이터 홈스크린에서 60pt 실루엣 확인
- [ ] 시뮬레이터 알림센터에서 28px 가독성 확인 (한글이 흐려도 딥 그린+크림 덩어리로 식별)
- [ ] 실기기(라이트·다크) 홈스크린에서 대비 확인
- [ ] Settings / Spotlight 40pt에서 식별
- [ ] App Store 미리보기용 1024 PNG 준비 완료

**금지 사항**

- 아이콘에 투명 영역 금지 (iOS 규정: 사각형 풀블리드 필요, squircle은 OS가 자동 마스킹)
- 라이트/다크 듀얼 아이콘 시도 (iOS 18 기본 아이콘은 컬러 고정, 딥 그린의 저명도가 자동 대비 확보)

### 4-5. 런치 스크린 (Launch Screen)

> 디자인 자산: `docs/icon/assets/v2/launch-logo.svg` (투명 배경, 로고만)
> 배경 색상: `#2E5D3A` (Theme/brand)
> 목적: 앱 아이콘 → 런치 화면 → 첫 화면의 시각 연속성 확보. 흰 화면(Xcode 자동 생성 빈 dict) 방지.

**구성 (UILaunchScreen 방식, iOS 14+ 권장)**

- 배경: 딥 그린 풀블리드 (`Theme/brand` 컬러셋)
- 중앙 이미지: "개발어원 사전" 크림 로고 (`LaunchLogo` 이미지셋, 2x/3x PNG)
- LaunchScreen.storyboard 사용하지 않음

**Info.plist 키**

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key><string>Theme/brand</string>
    <key>UIImageName</key><string>LaunchLogo</string>
    <key>UIImageRespectsSafeAreaInsets</key><true/>
</dict>
```

`INFOPLIST_KEY_UILaunchScreen_Generation = YES`(Xcode 자동 생성)는 빈 dict만 만들어 흰 화면이 됨. Info.plist에 명시한 키가 우선 적용되도록 위 dict 추가 필요.

**자산 익스포트**

```bash
rsvg-convert -w 480 -h 480 docs/icon/assets/v2/launch-logo.svg \
  -o DevEtym/DevEtym/Assets.xcassets/LaunchLogo.imageset/launch-logo@2x.png
rsvg-convert -w 720 -h 720 docs/icon/assets/v2/launch-logo.svg \
  -o DevEtym/DevEtym/Assets.xcassets/LaunchLogo.imageset/launch-logo@3x.png
```

**검증 체크리스트**

- [ ] 시뮬레이터 첫 실행 시 흰 화면 대신 딥 그린 + 로고 노출
- [ ] 노치/Dynamic Island 영역 침범 없음 (UIImageRespectsSafeAreaInsets)
- [ ] 라이트·다크 시스템 모두 동일 색상 (런치는 컬러 고정)
- [ ] 런치 → SearchView 전환 시 깜빡임 없음

**금지 사항**

- 런치 화면에 "Loading..." 텍스트, 스피너, 애니메이션 (Apple HIG 위반)
- 라이트/다크 색상 분기 (런치는 단일 컬러)
- 정적이지 않은 콘텐츠 (날짜·시간·사용자 데이터)

✅ Phase 4 완료 조건: 모든 Phase 1-3 기능 통합 동작, 오류 처리 완비, 앱 아이콘 적용 및 가독성 검증 완료, 런치 스크린 적용 완료
