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
   - 시스템 프롬프트에 error/suggestion 응답 구조 포함
   - 응답 파싱 전처리: ```json 마크다운 블록 제거 후 JSON 디코딩
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
   - 검색창 하단 안내 문구: "영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)"
   - 타이핑 중 자동완성 (termService.autocomplete 사용, 300ms 디바운스, 최소 1자)
   - 최근 검색 칩 (termService.recentSearches(limit: 5)), .onAppear에서 갱신
2. DetailView
   - TermResult 분기 처리: .found / .notDevTerm / .possibleTypo
   - .found 시 작명 이유 본문을 ScrollView로 감싸 긴 텍스트 대응
   - .possibleTypo 시 추천 용어 탭으로 재검색 (NavigationStack path 교체, push 아닌 replace)
   - 북마크 버튼 → termService.toggleBookmark(for:) 호출
   - 하단 오류 제보 mailto (용어 정보 자동 채움)
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

## 병합 순서

```bash
# 1. 서비스 레이어 먼저 머지
git merge feat/services

# 2. 번들 DB 머지 (충돌 없음)
git merge feat/bundle-db

# 3. UI 레이어 머지 (Mock → 실제 Service로 교체)
git merge feat/ui
# 이후 MockTermService 참조를 실제 TermService로 교체
```

### 머지 후 확인 사항
- [ ] MockTermService import를 실제 TermService로 교체
- [ ] ViewModel @Environment(\.termService) 주입이 실제 TermService 타입과 호환되는지 확인
- [ ] DevEtymApp.swift의 ModelContainer 설정에 Term, SearchHistory 등록 확인
- [ ] terms.json 200개 버전이 Resources/에 정상 포함 확인
- [ ] 전체 빌드 + 테스트 통과 확인
- [ ] 실제 기기에서 E2E 테스트: 번들 DB 검색 → AI 폴백 → 결과 표시 → 북마크 → 히스토리
