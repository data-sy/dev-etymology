# AGENTS.md — DevEtym 멀티 에이전트 작업 분배

> Git worktree를 사용해 각 에이전트가 독립 브랜치에서 작업
> **Phase 1이 완전히 완료된 상태에서** 멀티 에이전트 작업 시작
> Phase 1 산출물: Term.swift, SearchHistory.swift, TermEntry.swift, TermResult.swift, AIErrorResponse.swift, Constants.swift, EnvironmentKeys.swift, DevEtymApp.swift, 초기 terms.json (20개)

---

## 전제 조건

- Phase 1의 모든 모델/DTO/열거형/상수/EnvironmentKey/앱 진입점이 이미 구현되어 main에 머지된 상태
- 각 에이전트는 독립적인 git worktree에서 작업
- 에이전트 간 의존성 없는 작업만 병렬 처리
- **Phase 1에서 정의된 파일을 재생성하거나 덮어쓰지 말 것** (import하여 사용)

## worktree 세팅

```bash
# 메인 브랜치에서 각 에이전트용 브랜치 생성
git worktree add ../devetym-services feat/services
git worktree add ../devetym-ui feat/ui
git worktree add ../devetym-db feat/bundle-db
```

---

## 의존성 규칙

```
Agent A (Services)  ← 독립 작업
Agent B (UI)        ← MockTermService만 의존 (BundleDBService, ClaudeAPIService, modelContext 직접 참조 금지)
Agent C (Bundle DB) ← 독립 작업
```

> **핵심**: UI 레이어의 모든 ViewModel은 TermServiceProtocol에만 의존한다
> 검색, 자동완성, 북마크, 히스토리 CRUD 모두 TermServiceProtocol을 통해 호출한다
> View/ViewModel에서 SwiftData @Query를 직접 사용하지 않는다
> Agent B는 MockTermService 하나만 구현하면 모든 UI를 독립적으로 개발할 수 있다

---

## 에이전트 작업 분배

### Agent A — 서비스 레이어 (feat/services)

**담당 파일:**
- Services/BundleDBService.swift
- Services/ClaudeAPIService.swift
- Services/TermService.swift
- Tests/TermServiceTests.swift
- Tests/BundleDBServiceTests.swift
- Tests/ClaudeAPIServiceTests.swift
- Tests/Mocks/MockBundleDBService.swift
- Tests/Mocks/MockClaudeAPIService.swift

**⚠️ 주의: 아래 파일은 Phase 1에서 이미 생성됨. 재생성/덮어쓰기 금지, import하여 사용:**
- Models/Term.swift (convenience init(from:source:isBookmarked:), toEntry() 포함)
- Models/TermEntry.swift
- Models/TermResult.swift
- Models/AIErrorResponse.swift
- Utils/Constants.swift
- Utils/EnvironmentKeys.swift
- App/DevEtymApp.swift

**작업 지시:**
```
spec.md의 Phase 2를 구현하세요

Phase 1의 모델 파일은 이미 존재합니다 — 재생성하지 말고 import하여 사용하세요
Term.init(from:source:isBookmarked:)와 Term.toEntry() 편의 메서드가 이미 정의되어 있습니다

⚠️ @MainActor 필수:
TermServiceProtocol과 TermService는 반드시 @MainActor로 선언하세요
SwiftData mainContext는 메인 스레드 전용이므로,
async 작업(ClaudeAPIService 호출) 후 modelContext에 접근할 때
@MainActor가 없으면 런타임 크래시가 발생합니다

구현 순서:
1. BundleDBService: keyword + aliases 대소문자 무시 매칭 + autocomplete
2. ClaudeAPIService:
   - API 키 검증 (Bundle.main에서 읽기 실패/빈 문자열 → .invalidAPIKey)
   - 시스템 프롬프트에 error/suggestion 응답 구조 + 엄격한 출력 제한 포함
   - 응답 파싱 전처리: ```json 마크다운 블록 제거 후 JSON 디코딩
   - 선택적 개선: 텍스트 프롬프트 기반 JSON 파싱 대신, Anthropic API의 Tool Use(기능 호출)를 사용하여
     TermEntry 스키마를 강제하는 방식도 고려하세요 (구조화된 출력 보장)
3. TermService (@MainActor, TermServiceProtocol 전체 구현):
   - fetch: 오케스트레이션 (Bundle → SwiftData 캐시 → AI 폴백)
   - autocomplete: BundleDBService 위임
   - toggleBookmark: SwiftData Term upsert + isBookmarked 토글
   - bookmarkedTerms: isBookmarked == true 조회
   - recentSearches: searchedAt 내림차순 조회
   - deleteSearchHistory / clearAllSearchHistory
   - 입력 정규화 (trim + lowercase), 빈 문자열은 즉시 .notDevTerm
   - AI 오류 응답 분기 처리 (NOT_DEV_TERM, POSSIBLE_TYPO)
   - SearchHistory는 성공 시에만 upsert (동일 keyword 존재 시 searchedAt 갱신)
   - Term upsert: 동일 keyword 존재 시 필드 업데이트 (isBookmarked, source 보존)

각 Service는 Protocol로 추상화하세요
모든 Service에 대응하는 테스트를 작성하세요
AI 오류 응답 분기 테스트를 반드시 포함하세요
마크다운 블록 감싸기 응답 파싱 테스트를 포함하세요
Phase 2 완료 조건을 충족하면 작업을 종료하세요
```

### Agent B — UI 레이어 (feat/ui)

**담당 파일:**
- Features/Search/SearchView.swift
- Features/Search/SearchViewModel.swift
- Features/Detail/DetailView.swift
- Features/Detail/DetailViewModel.swift
- Features/Bookmark/BookmarkView.swift
- Features/Bookmark/BookmarkViewModel.swift
- Features/History/HistoryView.swift
- Features/History/HistoryViewModel.swift
- Features/Onboarding/OnboardingView.swift
- App/ContentView.swift
- Tests/Mocks/MockTermService.swift

**작업 지시:**
```
spec.md의 Phase 3을 구현하세요

⚠️ Phase 1 파일 보호:
App/DevEtymApp.swift와 Utils/EnvironmentKeys.swift는 절대 수정하지 마세요 (Phase 1 유지)
모든 View의 #Preview 안에서만 .environment(\.termService, MockTermService())를 주입하여 UI를 테스트하세요

⚠️ 핵심 의존성 규칙 (예외 없음):
- 모든 ViewModel은 TermServiceProtocol에만 의존하세요
- BundleDBService, ClaudeAPIService, modelContext를 직접 import하거나 참조하지 마세요
- SwiftData @Query를 View/ViewModel에서 직접 사용하지 마세요
- 북마크 토글, 히스토리 조회/삭제 모두 TermServiceProtocol 메서드를 통해 호출하세요
- ViewModel에서 TermService는 @Environment(\.termService)로 주입받으세요
- 모든 ViewModel은 @MainActor로 선언하세요

⚠️ 상태 동기화 (중요):
@Query를 사용하지 않으므로 SwiftData 변경이 자동 반영되지 않습니다
아래 패턴을 반드시 지켜야 UI가 정상 갱신됩니다:
- 북마크 토글, 히스토리 삭제, 전체 삭제 등 데이터 변경 액션 직후
  ViewModel이 조회 메서드(bookmarkedTerms, recentSearches 등)를 다시 호출하여 배열 갱신
- 모든 목록 View(Bookmark, History, Search의 최근 검색 칩)는
  .onAppear 시점에도 데이터를 최신화

⚠️ 검색 Task 관리:
SearchViewModel과 DetailViewModel은 private var currentSearchTask: Task<Void, Never>? 보유
새로운 검색 시작 시 기존 Task를 cancel() 처리 후 새 Task 할당
연타/빠른 재검색 시 레이스 컨디션 방지

MockTermService 구현 (Tests/Mocks/MockTermService.swift):
- @MainActor로 선언
- TermServiceProtocol 전체를 준수
- fetch(keyword:) → 미리 정의된 TermResult 반환
- autocomplete(prefix:) → 미리 정의된 [TermEntry] 반환
- toggleBookmark(for:) → Bool 토글 반환
- bookmarkedTerms() → 미리 정의된 [Term] 반환
- recentSearches(limit:) → 미리 정의된 [SearchHistory] 반환
- deleteSearchHistory(_:) / clearAllSearchHistory() → 빈 구현
- .notDevTerm, .possibleTypo 케이스도 Mock 데이터로 테스트 가능하게

주요 구현 사항:
1. SearchView
   - 네비게이션: @State private var path = NavigationPath() 소유
   - NavigationStack(path: $path)으로 바인딩
   - possibleTypo 재검색: path.removeLast() 후 새 keyword append
   - 검색창 하단 안내 문구: "영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)"
   - 타이핑 중 자동완성 (termService.autocomplete 사용, 300ms 디바운스, 최소 1자)
   - 최근 검색 칩 (termService.recentSearches(limit: 5)), .onAppear에서 갱신
2. DetailView
   - TermResult 분기 처리: .found / .notDevTerm / .possibleTypo
   - .found 시 작명 이유 본문을 ScrollView로 감싸 긴 텍스트 대응
   - .possibleTypo 시 추천 용어 탭으로 재검색 (NavigationStack path 교체, push 아닌 replace)
   - 북마크 버튼 → termService.toggleBookmark(for:) 호출
   - 하단 오류 제보 mailto (용어 정보 자동 채움)
   - 에러 처리: ViewModel이 catch → @Published var errorMessage로 Alert 표시
     - .invalidAPIKey → "API 키 설정이 필요합니다"
     - .timeout → "요청 시간이 초과되었습니다. 다시 시도해주세요"
     - .networkError → URLError.code 세분화 (.notConnectedToInternet 등)
     - .invalidResponse → "응답을 처리할 수 없습니다"
     - 기타 → "오류가 발생했습니다" + 제보 유도
3. BookmarkView
   - termService.bookmarkedTerms()로 목록 조회, .onAppear에서 갱신
   - 스와이프 → termService.toggleBookmark(for:) 호출 → 직후 목록 다시 조회
4. HistoryView
   - termService.recentSearches(limit:)로 목록 조회, .onAppear에서 갱신
   - 스와이프 삭제 → termService.deleteSearchHistory(_:) → 직후 목록 다시 조회
   - 전체 삭제 → termService.clearAllSearchHistory() → 직후 목록 다시 조회
5. OnboardingView: AI 생성 고지 포함, AppStorage 플래그
6. 네비게이션: NavigationStack + .navigationDestination(for:) 패턴

Constants.swift와 EnvironmentKeys.swift는 Phase 1에서 이미 생성됨 — 참조만 하세요
모든 View에 #Preview 매크로를 포함하세요 (Preview에서는 MockTermService 사용)
Phase 3 완료 조건을 충족하면 작업을 종료하세요
```

### Agent C — 번들 DB 생성 (feat/bundle-db)

**담당 파일:**
- Resources/terms.json
- Scripts/generate_db.py

**작업 지시:**
```
terms.json에 들어갈 200개 용어를 생성하세요
기존 Phase 1의 초기 20개 용어를 반드시 포함한 상태에서 확장할 것
기존 용어의 keyword와 aliases를 변경하지 말 것 (Agent A 테스트가 "mutex" 등을 전제)
spec.md의 terms.json 스키마를 따르세요

aliases 규칙:
- 한글 표기 (예: "뮤텍스", "제이피에이") — 최소 1개 필수
- 풀네임 (예: "mutual exclusion", "java persistence api")
- 대소문자 변형은 검색 로직에서 처리하므로 aliases에 중복 불필요

카테고리별 분배:
- 동시성/병렬: mutex, semaphore, deadlock, race condition 등 (30개)
- 자료구조: stack, queue, heap, tree, graph 등 (30개)
- 네트워크: socket, handshake, latency, payload, DNS 등 (30개)
- DB: index, transaction, schema, shard, cursor 등 (30개)
- 패턴/아키텍처: singleton, factory, observer, MVC 등 (30개)
- 기타 핵심: bug, cache, compile, debug, daemon 등 (50개)

Scripts/generate_db.py는 Claude API를 호출해 배치 생성하는 스크립트입니다
모델: Constants와 동일하게 claude-sonnet-4-5-20250514 사용

생성 후 검증 규칙 (generate_db.py에 포함):
1. 모든 용어에 aliases 배열 존재 (빈 배열 금지, 최소 1개 이상)
2. 각 용어에 한글 표기 alias 최소 1개 포함
3. keyword는 영문 소문자만 허용 (공백, 특수문자 금지 — 단, 하이픈과 언더스코어는 허용)
4. 모든 필드(keyword, aliases, summary, etymology, namingReason)가 비어있지 않음
5. keyword 중복 없음
6. 최종 JSON의 유효성 (json.loads 통과)
7. 총 200개 이상
검증 실패 시 스크립트가 에러 로그를 출력하고 종료할 것
```

---

## A/B/C 병합 순서

```bash
# 1. 서비스 레이어 먼저 머지
git merge feat/services

# 2. 번들 DB 머지 (충돌 없음)
git merge feat/bundle-db

# 3. UI 레이어 머지
git merge feat/ui
```

### A/B/C 머지 후 확인 사항
- [ ] DevEtymApp.swift가 Phase 1 원본 상태 유지 확인 (Agent B가 수정하지 않았는지)
- [ ] ViewModel이 @Environment(\.termService)로 실제 TermService를 정상 수신하는지 확인
- [ ] Preview에서만 MockTermService 사용, 실제 앱에서는 TermService 사용 확인
- [ ] terms.json 200개 버전이 Resources/에 정상 포함 확인
- [ ] 전체 빌드 + 테스트 통과 확인
- [ ] `ClaudeAPIError` 같은 타입 중복 선언 없는지 컴파일 확인 (파일명이 다르면 git이 충돌로 감지하지 못함)

---

## 마무리 단계 — Agent D, E

A/B/C 머지 후 남은 작업을 2명이 병렬로 처리. D와 E는 서로 다른 영역을 건드려 충돌이 없다.

### worktree 세팅

```bash
git worktree add ../devetym-finishing -b feat/finishing-touches
git worktree add ../devetym-a11y      -b feat/accessibility
```

### 의존성 규칙

```
Agent D (마무리 배선)  ← 설정 파일과 테스트 타겟 정리
Agent E (접근성)       ← Features/*/View.swift만 수정
```

> D와 E는 건드리는 파일군이 완전히 분리됨 (D: 설정/Info.plist/Tests 폴더, E: UI View 파일).
> 같은 시점에 병렬로 진행 가능하며, 어느 쪽이 먼저 머지돼도 충돌 없음.

### Agent D — 마무리 배선 (feat/finishing-touches)

**담당 파일:**
- `DevEtym/DevEtymTests/Mocks/MockTermService.swift` (이동 대상)
- `DevEtym/DevEtym/Tests/` (삭제 대상 — 빈 폴더)
- `DevEtym/DevEtym/Info.plist`
- `DevEtym/DevEtym.xcodeproj/project.pbxproj`
- `Config.xcconfig` (신규, `.gitignore` 처리)
- `Config.sample.xcconfig` (신규, 커밋)
- `.gitignore`

**작업 지시:**
```
A/B/C 머지 후 남은 마무리 배선 두 가지를 처리한다

1. MockTermService 위치 수정
- 현재 `DevEtym/DevEtym/Tests/Mocks/MockTermService.swift`에 잘못 생성되어 앱 타겟에 포함된 상태
- `DevEtym/DevEtymTests/Mocks/MockTermService.swift`로 이동 (테스트 타겟)
- 빈 `DevEtym/DevEtym/Tests/` 폴더 제거
- 이동 후 기존 MockTermService 참조(Preview 등)가 여전히 유효한지 확인

2. Claude API 키 실제 주입 배선
- `Config.xcconfig` 생성 (실제 키 담는 파일, `.gitignore` 처리)
  예: `CLAUDE_API_KEY = sk-ant-xxxxx`
- `Config.sample.xcconfig` 생성 (빈 키, 커밋 대상) — 다른 개발자용 가이드
- Xcode 빌드 설정의 Configurations에 xcconfig 연결 (Debug/Release 모두)
- `Info.plist`의 `CLAUDE_API_KEY` 값을 `$(CLAUDE_API_KEY)` 변수로 치환
- `.gitignore`에 `Config.xcconfig` 추가
- ClaudeAPIService가 Bundle.main에서 읽는 코드는 이미 있음 — 수정 불필요

검증:
- xcconfig 연결 후 실제 키를 넣고 빌드해서 Bundle.main.infoDictionary["CLAUDE_API_KEY"]가 읽히는지 런타임 확인
- Config.xcconfig가 git에 커밋되지 않음을 확인

논리 단위로 Conventional Commits 커밋. push/PR은 하지 마. 커밋까지만.
```

### Agent E — 접근성 (feat/accessibility)

**담당 파일:**
- `DevEtym/DevEtym/Features/Search/SearchView.swift`
- `DevEtym/DevEtym/Features/Detail/DetailView.swift`
- `DevEtym/DevEtym/Features/Bookmark/BookmarkView.swift`
- `DevEtym/DevEtym/Features/History/HistoryView.swift`
- `DevEtym/DevEtym/Features/Onboarding/OnboardingView.swift`
- `DevEtym/DevEtym/App/ContentView.swift` (TabView 라벨 접근성)

**작업 지시:**
```
spec.md Phase 4-2 접근성 작업과 CLAUDE.md의 다크모드 대응 검증을 수행한다

1. 접근성 라벨 추가
- 모든 Image/SF Symbol에 `accessibilityLabel("...")` 추가
- 북마크 버튼, 삭제 스와이프, 제보 버튼 등 의미 있는 상호작용 요소에 라벨
- 아이콘만 있는 탭바 아이템에 라벨 보강

2. Dynamic Type 지원
- 모든 텍스트에 `.font(.body)`, `.font(.title2)` 등 시스템 폰트 스타일 사용 확인
- 고정 `.font(.system(size: 16))` 같은 표현 있으면 Dynamic Type 지원 스타일로 교체
- 큰 텍스트 크기에서 레이아웃 깨지지 않는지 확인 (accessibility inspector 또는 시뮬레이터 환경설정)

3. 다크모드 검증
- 시스템 다크모드로 전환 시 모든 화면이 정상 렌더링되는지 확인
- 커스텀 컬러가 있다면 Color asset 또는 `.init(light:dark:)` 사용 확인
- 하드코딩된 `.white`, `.black` 없는지 확인

⚠️ 건드리지 말 것:
- Services/, Models/, Utils/, Resources/, App/DevEtymApp.swift
- 로직/데이터 흐름 변경 금지 — 오직 UI 접근성 보강만

논리 단위로 Conventional Commits 커밋. push/PR은 하지 마. 커밋까지만.
```

### D/E 병합 순서

```bash
# 순서 무관 (충돌 없음)
git merge feat/finishing-touches
git merge feat/accessibility
```

### D/E 머지 후 남은 작업

- **E2E 통합 테스트** (Task 3): 시뮬레이터에서 검색 → 번들 히트 → AI 폴백 → 결과 → 북마크 → 히스토리 풀 플로우 검증. 발견되는 버그는 유형별로 별도 브랜치(예: `fix/<area>`)에서 수정
- **배포 단계** (spec 밖): 앱 아이콘, 스크린샷, App Store Connect 등록
