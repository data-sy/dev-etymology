# spec.md — DevEtym 구현 명세서 (Claude Code 전용)

> 이 문서는 Claude Code가 참조하는 구현 명세입니다.
> Xcode 프로젝트 설정, 인프라, 배포 등 인간 작업은 CHECKLIST.md를 참조하세요.
> CLAUDE.md의 코딩 규칙을 반드시 준수하세요.

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

> **TermEntry ↔ Term 변환 시 aliases를 반드시 포함할 것.**
> 번들 용어 북마크, AI 응답 캐시 모두 aliases가 보존되어야 함.

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
    static let claudeModel = "claude-sonnet-4-5"
    static let apiTimeout: TimeInterval = 30
}
```

### 1-4. 초기 번들 DB

**Resources/terms.json** — 20개 용어로 시작
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
스키마: keyword(필수), aliases(필수, 빈 배열 허용), summary, etymology, namingReason

✅ Phase 1 완료 조건: 모든 모델 파일 컴파일 오류 없음

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
당신은 개발 용어의 어원을 설명하는 전문가입니다.
사용자가 입력한 개발 용어에 대해 반드시 아래 JSON 형식으로만 응답하세요.
다른 텍스트, 마크다운 코드 블록, 설명을 절대 추가하지 마세요.

## 정상 응답 (개발 용어인 경우)
{
  "keyword": "정규화된 용어 (영문)",
  "aliases": ["대체 표기 1", "대체 표기 2"],
  "summary": "한 줄 요약 (한국어, 20자 이내)",
  "etymology": "어원 설명 (한국어, 원어 표기 포함)",
  "namingReason": "왜 이 이름이 붙었는지 설명 (한국어, 3-5문장)"
}

## 오류 응답
- 개발 용어가 아닌 경우:
  {"error": "NOT_DEV_TERM", "suggestion": null}
- 오타로 추정되는 경우:
  {"error": "POSSIBLE_TYPO", "suggestion": "올바른 용어"}
```

**응답 파싱 로직:**
1. JSON 디코딩 시도
2. "error" 키 존재 → AIErrorResponse로 디코딩
   - NOT_DEV_TERM → throw ClaudeAPIError.notDevTerm
   - POSSIBLE_TYPO → throw ClaudeAPIError.possibleTypo(suggestion:)
3. "error" 키 없음 → TermEntry로 디코딩

### 2-3. TermService (오케스트레이터)

**Services/TermService.swift**

```swift
protocol TermServiceProtocol {
    func fetch(keyword: String) async throws -> TermResult
    func autocomplete(prefix: String) -> [TermEntry]
}
```

> **autocomplete도 TermServiceProtocol에 포함.**
> UI 레이어는 TermServiceProtocol만 의존하며, BundleDBService를 직접 참조하지 않는다.
> 이를 통해 멀티 에이전트 작업 시 UI 에이전트가 MockTermService 하나만 의존하면 된다.

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

**오케스트레이션 순서:**
1. 입력 정규화
2. BundleDBService.search(keyword) → 히트 시 `.found` 반환 + 히스토리 저장
3. SwiftData에서 Term 조회 (keyword 매칭) → 히트 시 `.found` 반환 + 히스토리 저장
4. ClaudeAPIService.generate(keyword) 호출
   - 성공 → SwiftData에 Term 캐시 저장 (source: "ai", aliases 포함) + 히스토리 저장 + `.found` 반환
   - .notDevTerm → `.notDevTerm` 반환 (히스토리 저장 안 함)
   - .possibleTypo → `.possibleTypo(suggestion)` 반환 (히스토리 저장 안 함)
   - 기타 에러 → throw (히스토리 저장 안 함)

**SwiftData 저장 시점 (lazy 전략):**
- AI 응답 시 → Term으로 저장 (source: "ai", aliases 포함, isBookmarked: false)
- 북마크 시 → ViewModel에서 처리
  - SwiftData에 Term 존재 → isBookmarked = true
  - 미존재 (번들 용어) → TermEntry → Term 변환 저장 (source: "bundle", aliases 포함, isBookmarked: true)

**히스토리 저장:**
- fetch 성공(.found) 시에만 SearchHistory 저장/갱신
- #Unique로 동일 키워드는 searchedAt만 업데이트

### 2-4. 테스트

**Tests/TermServiceTests.swift**
- test_fetch_bundleHit_returnsImmediately
- test_fetch_bundleAlias_returnsCorrectTerm
- test_fetch_bundleMiss_callsClaudeAPI
- test_fetch_cachedResult_skipsAPI
- test_fetch_apiError_throwsError
- test_fetch_notDevTerm_returnsNotDevTerm
- test_fetch_possibleTypo_returnsSuggestion
- test_fetch_success_savesHistory
- test_fetch_failure_doesNotSaveHistory
- test_autocomplete_delegatesToBundleDB

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

✅ Phase 2 완료 조건: 모든 테스트 통과, Mock으로 API 호출 검증

---

## Phase 3 — UI 구현

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

> **SearchViewModel은 TermServiceProtocol에만 의존한다.**
> BundleDBService를 직접 참조하지 않는다.

**상태:**
- 검색어 입력 → 엔터/검색 버튼 → DetailView push
- 검색창 하단 안내 문구: "영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)"
- 타이핑 중 자동완성: TermServiceProtocol.autocomplete(prefix:) → 드롭다운 리스트
- 최근 검색 칩: SearchHistory 최근 5개 표시
- 칩 탭 → 해당 용어로 DetailView push

### 3-3. DetailView + DetailViewModel

> **DetailViewModel은 TermServiceProtocol에만 의존한다.**

**TermResult별 표시:**

`.found(TermEntry)`:
- 용어명 (large title)
- 한 줄 요약
- 어원 블록 (좌측 accent 보더)
- 작명 이유 본문 — **ScrollView로 감싸서 긴 텍스트 대응**
- 북마크 버튼 (toolbar)
- 하단 고정: 오류 제보 버튼

`.notDevTerm`:
- "개발 용어를 검색해주세요" 안내 화면
- 검색으로 돌아가기 버튼

`.possibleTypo(suggestion)`:
- "{suggestion}을(를) 찾으셨나요?" 안내
- 추천 용어 탭 시 해당 용어로 재검색

**로딩 상태:**
- 번들 DB 히트: 로딩 없음
- AI 생성 중: ProgressView + "어원을 분석하는 중..." 텍스트

**북마크 로직 (ViewModel에서 처리):**
```
북마크 탭 →
  SwiftData에 Term 존재? → isBookmarked 토글
  미존재 (번들 용어)? → TermEntry → Term(source: "bundle", aliases 포함, isBookmarked: true) 저장
```

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

- SwiftData Query: isBookmarked == true
- 빈 상태: 안내 문구
- 항목 탭 → DetailView push
- 스와이프 삭제 → isBookmarked = false

### 3-6. HistoryView + HistoryViewModel

- SearchHistory 최근 검색순 정렬 (searchedAt 내림차순)
- 항목 탭 → DetailView push
- 스와이프 삭제
- 상단 "전체 삭제" 버튼

### 3-7. OnboardingView

- 앱 첫 실행 시 1회만 표시 (@AppStorage("hasSeenOnboarding") 플래그)
- 표시 내용:
  - 앱 소개 (1-2문장)
  - "이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 제보해 주세요."
  - 시작하기 버튼

✅ Phase 3 완료 조건: 모든 탭 화면 렌더링, 검색 → 결과 플로우 동작, 오류 제보 mailto 동작

---

## Phase 4 — 통합 및 마무리

### 4-1. 오류 처리 UI
- API 타임아웃: "잠시 후 다시 시도해주세요" Alert
- 네트워크 없음: "인터넷 연결을 확인해주세요" Alert
- 알 수 없는 오류: "오류가 발생했습니다" + 제보 유도

### 4-2. 접근성
- 모든 이미지/아이콘에 accessibilityLabel 추가
- Dynamic Type 지원 확인

### 4-3. 번들 DB 확장
- 초기 20개 → Claude API 배치 생성 스크립트로 200개로 확장
- 스크립트: Scripts/generate_db.py
- 각 용어에 aliases 포함 필수
- 생성 후 JSON 유효성 + aliases 존재 여부 검증

✅ Phase 4 완료 조건: 모든 Phase 1-3 기능 통합 동작, 오류 처리 완비
