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
모델: Constants와 동일하게 claude-sonnet-4-6 사용

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

## 마무리 단계 — Agent D, E (순차)

A/B/C 머지 후 와이어프레임(`devetym-wireframe-v2.html`) 기반 디자인 확장 + 마무리 배선 + 접근성까지 두 에이전트가 **순차**로 처리.

병렬로 쪼갤 수도 있으나, E의 UI 작업이 D의 데이터 모델 변경(카테고리 필드 추가)에 의존하므로 **D 머지 후 E 시작**이 깔끔하다.

### worktree 세팅

**Agent D 착수 시점:**
```bash
git worktree add ../devetym-data -b feat/data-extension-and-wiring
```

**Agent E 착수 시점 (D 머지 후 main에서 분기):**
```bash
git checkout main && git pull
git worktree add ../devetym-ui-v2 -b feat/ui-design-and-a11y
```

### Agent D — 데이터 확장 & 마무리 배선 (feat/data-extension-and-wiring)

**담당 파일:**
- `DevEtym/DevEtym/Models/TermEntry.swift` — `category` 필드 추가
- `DevEtym/DevEtym/Models/Term.swift` — `category` 필드 추가, 변환 메서드 갱신, `#Index<Term>([\.category])` 추가
- `DevEtym/DevEtym/Services/ClaudeAPIService.swift` — 시스템 프롬프트에 category 규칙 추가
- `DevEtym/DevEtym/Resources/terms.json` — 기존 200개에 category 필드 채우기
- `Scripts/generate_db.py` — 프롬프트 & 검증 로직에 category 반영
- `DevEtym/DevEtym/Services/BundleDBService.swift` — Codable 디코딩 자동 반영되나 테스트/목업 업데이트 필요
- `DevEtym/DevEtymTests/Mocks/MockTermService.swift` (이동 대상)
- `DevEtym/DevEtym/Tests/` (삭제 대상 — 빈 폴더)
- `DevEtym/DevEtym/Info.plist`
- `DevEtym/DevEtym.xcodeproj/project.pbxproj`
- `Config.xcconfig` (신규, `.gitignore` 처리)
- `Config.sample.xcconfig` (신규, 커밋)
- `.gitignore`
- 기존 테스트 파일들 — 생성자/DTO 시그니처 변경 반영

**작업 지시:**
```
spec.md와 CLAUDE.md를 읽은 뒤, 이번 버전에 추가된 카테고리 필드 도입과 마무리 배선을 처리한다

1. TermEntry에 category 필드 추가
- struct TermEntry에 `let category: String` 추가
- 카테고리 값은 6개 고정 집합: "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"

2. Term(@Model)에 category 필드 추가
- `var category: String` 추가, init 파라미터에도 포함
- `#Index<Term>([\.isBookmarked], [\.createdAt], [\.category])`로 인덱스 확장
- convenience init(from:source:isBookmarked:)에서 entry.category 전달
- toEntry()에서 category 포함
- SwiftData 마이그레이션 주의: 배포 전 개발 단계이므로 앱 삭제/시뮬레이터 데이터 리셋으로 충분. VersionedSchema는 이번엔 도입하지 않음 (spec 1-1의 주의 참고)

3. ClaudeAPIService 시스템 프롬프트 갱신
- 응답 JSON에 category 필드 필수 명시
- 6개 고정 카테고리 값만 허용한다는 규칙 추가
- 6개에 애매하면 가장 핵심 분류, 어디에도 안 맞으면 "기타" 규칙 추가
- 프롬프트 본문은 spec.md Phase 2-2를 그대로 반영

4. terms.json 200개에 category 채우기
- 기존 용어들을 6개 카테고리 중 하나로 분류하여 필드 추가
- spec AGENTS.md의 카테고리별 분배(동시성/자료구조/네트워크/DB/패턴/기타)를 그대로 준용
- 기존 keyword와 aliases는 변경하지 말 것 (하위 호환)

5. generate_db.py 업데이트
- 프롬프트에 category 요구 포함
- 검증 규칙에 "category 필드 존재 + 6개 값 중 하나" 추가
- 검증 실패 시 에러 로그 후 종료

6. MockTermService 위치 수정
- `DevEtym/DevEtym/Tests/Mocks/MockTermService.swift` → `DevEtym/DevEtymTests/Mocks/MockTermService.swift`로 이동
- 빈 `DevEtym/DevEtym/Tests/` 폴더 제거
- Mock도 category 필드 반영되도록 기본값 포함

7. Claude API 키 xcconfig 배선
- `Config.xcconfig` 생성 (실제 키 담는 파일, `.gitignore` 처리)
- `Config.sample.xcconfig` 생성 (빈 키, 커밋 대상)
- Xcode 빌드 설정의 Configurations에 xcconfig 연결 (Debug/Release 모두)
- Info.plist의 CLAUDE_API_KEY 값을 `$(CLAUDE_API_KEY)`로 치환
- .gitignore에 Config.xcconfig 추가
- 런타임에 Bundle.main.infoDictionary["CLAUDE_API_KEY"]가 읽히는지 확인

8. 기존 테스트 갱신
- TermEntry/Term 생성자 호출부에 category 추가
- MockClaudeAPIService/MockBundleDBService 반환값도 category 포함
- 기존 테스트가 깨지지 않도록 sample TermEntry 헬퍼가 있으면 거기부터 수정

⚠️ 건드리지 말 것:
- Features/*/View.swift (E 담당)
- 다크모드 컬러/폰트 (E 담당)
- Phase 1 원본 구조 (App/DevEtymApp.swift는 xcconfig 연결을 위한 빌드 설정 변경만 허용)

검증:
- 빌드 통과
- 단위 테스트 통과 (카테고리 필드 반영된 상태로)
- Config.xcconfig가 git에 커밋되지 않음 확인

논리 단위로 Conventional Commits 커밋. push/PR은 하지 마. 커밋까지만.
```

### Agent E — UI 디자인 & 기능 & 접근성 (feat/ui-design-and-a11y)

**선행 조건:** Agent D가 머지되어 main에 category 필드가 반영된 상태. E는 main에서 분기.

**담당 파일:**
- `DevEtym/DevEtym/Features/Search/SearchView.swift`
- `DevEtym/DevEtym/Features/Detail/DetailView.swift`
- `DevEtym/DevEtym/Features/Detail/DetailViewModel.swift` — source(AI 여부) 전달
- `DevEtym/DevEtym/Features/Bookmark/BookmarkView.swift`
- `DevEtym/DevEtym/Features/Bookmark/BookmarkViewModel.swift`
- `DevEtym/DevEtym/Features/History/HistoryView.swift`
- `DevEtym/DevEtym/Features/History/HistoryViewModel.swift`
- `DevEtym/DevEtym/Features/Onboarding/OnboardingView.swift`
- `DevEtym/DevEtym/App/ContentView.swift`
- `DevEtym/DevEtym/Resources/Assets.xcassets/` — 팔레트 컬러 추가
- `DevEtym/DevEtym/Resources/Fonts/` — DM Sans/Mono/Serif Display 파일 (Google Fonts OFL)
- `DevEtym/DevEtym/Info.plist` — UIAppFonts 배열

**작업 지시:**
```
spec.md(특히 Phase 3-0-1 디자인 시스템, 3-3, 3-5, 3-6, 4-2)와 devetym-wireframe-v2.html을 참고해
와이어프레임에 정의된 디자인을 UI에 반영하고 접근성을 마무리한다

1. 디자인 시스템 도입 (컬러)
- Asset Catalog에 다음 컬러를 추가 (다크모드 우선, 라이트모드는 적당한 대응값):
  bg, surface, surface2, border, accent(#c8f060), accent2(#60c8f0), accentAI(#f0a060),
  text, textDim, textMuted
- 모든 View에서 하드코딩된 .white/.black 제거, 위 컬러 참조로 교체
- 시스템 다크모드 전환 시 정상 렌더링 확인

2. 디자인 시스템 도입 (폰트)
- Google Fonts에서 DM Sans, DM Mono, DM Serif Display를 OFL 라이선스로 다운로드
- Resources/Fonts/에 포함, Info.plist UIAppFonts 배열에 등록
- 사용 시 .font(.custom("DMSans-Regular", size: 13, relativeTo: .body)) 패턴으로 Dynamic Type 연계
- 본문: DM Sans, 코드·라벨·칩: DM Mono, 용어명·섹션 타이틀: DM Serif Display

3. DetailView 기능 추가
- 카테고리 태그 배지 (accent, 5px radius, DM Mono 9px uppercase)
  예: "동시성 · Concurrency" 형태. 영문 표기는 간단한 매핑 상수 사용(동시성→Concurrency 등)
- AI 생성 뱃지 (accentAI) — source == "ai" 인 경우에만 표시
  → ViewModel에서 DetailView로 TermEntry와 함께 isAIGenerated Bool 전달
  → TermService의 결과 흐름에서 Term.source를 조회해 전달하는 경로 추가
  → 단, ViewModel은 여전히 TermServiceProtocol에만 의존해야 하므로, fetch 결과에 source를 포함하는 방식 필요
    · 옵션 1(권장): TermResult.found의 연관값을 (TermEntry, source: String)으로 확장
    · 옵션 2: 별도 presentation 구조체 도입
  → 옵션 1을 채택하는 경우 Services 측 변경도 수반되므로 사전에 허용 범위(TermResult 시그니처 변경)만 소폭 확장
- 공유 버튼: ShareLink로 "{keyword}\n\n{summary}\n\n— DevEtym" 공유
- 북마크 버튼과 공유 버튼을 action-row로 나란히 배치

4. HistoryView 상대 시간
- RelativeDateTimeFormatter(unitsStyle: .full), 한국어 로케일
- "방금 전", "1시간 전", "어제", "3일 전" 같은 표시

5. BookmarkView 미리보기
- 각 항목에 keyword 아래로 summary 한 줄(또는 aliases 첫 요소)을 미리보기로 추가
- DM Mono 13px 용어 + 본문 텍스트 10px 미리보기

6. 접근성 (Phase 4-2)
- 모든 Image/SF Symbol에 accessibilityLabel
- 탭바 아이템, 북마크/공유/삭제 스와이프, 제보 버튼 등 상호작용 요소 라벨
- Dynamic Type 연계 확인 (.font(.custom(..., relativeTo: .body)))
- 큰 텍스트 크기에서 레이아웃 깨지지 않는지 확인

⚠️ 주의:
- TermResult 시그니처 확장(옵션 1 채택 시)은 Services/TermService.swift와 TermServiceProtocol.swift 수정을 동반함.
  이는 예외적으로 허용. 단, 테스트와 MockTermService 갱신 필수.
- Models/Term.swift, TermEntry.swift는 이미 D가 갱신한 상태 — 추가 수정 금지
- 로직/데이터 흐름 변경은 "source 전달 경로 확장"과 "공유 문구 구성"만. 나머지 로직 변경 금지

논리 단위로 Conventional Commits 커밋. push/PR은 하지 마. 커밋까지만.
```

### D/E 병합 순서

```bash
# D를 먼저 머지 (데이터 모델 변경이 main에 들어간 상태에서 E 시작)
git merge feat/data-extension-and-wiring

# D 머지 후 main에서 E 브랜치 생성하여 작업
# E 머지
git merge feat/ui-design-and-a11y
```

### D/E 머지 후 — Agent F

---

## 설정 화면 — Agent F

D/E 머지 후, E2E 검증 중 발견된 부재 기능: 다크/라이트 외관 전환 UI, 앱 정보, 법적 고지 등을 한데 모은 설정 탭.

### Agent F — 설정 화면 (feat/settings)

**선행 조건:** Agent D/E 머지 완료. main에서 분기.

**담당 파일:**
- `DevEtym/DevEtym/Features/Settings/SettingsView.swift` (신규)
- `DevEtym/DevEtym/App/ContentView.swift` — TabView에 설정 탭 추가
- `DevEtym/DevEtym/App/DevEtymApp.swift` 또는 `ContentView.swift` — preferredColorScheme 바인딩

**작업 지시:**
```
spec.md의 Phase 3-8 SettingsView 섹션과 CLAUDE.md를 읽고 설정 화면을 구현한다

1. SettingsView 구현 (Features/Settings/SettingsView.swift)
- ViewModel 불필요 — 순수 UI + 시스템 API 호출
- List + Section 패턴으로 구성

[외관 섹션]
- 화면 모드 Picker: 시스템 / 라이트 / 다크
  · @AppStorage("appearanceMode") var appearanceMode: Int = 0
  · 0: 시스템, 1: 라이트, 2: 다크

[앱 정보 섹션]
- 앱 버전: Bundle.main의 CFBundleShortVersionString
- 빌드 번호: Bundle.main의 CFBundleVersion

[지원 섹션]
- "개발자에게 문의" → mailto:Constants.reportEmail
- "앱 평가하기" → @Environment(\.requestReview)
- "오류 제보" → mailto:Constants.reportEmail (제목: "[오류제보] 일반")

[법적 고지 섹션]
- "오픈소스 라이선스" → NavigationLink로 하위 화면, DM Fonts OFL 라이선스 텍스트
- "AI 생성 고지" → "이 앱의 모든 어원 설명은 AI(Claude)가 생성합니다. 부정확한 내용이 포함될 수 있습니다."
- "개인정보 처리방침" → 외부 URL (Link, 아직 URL 미정이면 placeholder)

2. ContentView TabView에 설정 탭 추가
- .tabItem { Label("설정", systemImage: "gearshape") }
- 네 번째 탭으로 배치

3. 외관 모드 적용
- ContentView 또는 DevEtymApp의 WindowGroup 레벨에서 .preferredColorScheme() 적용
  · appearanceMode == 0 → nil (시스템)
  · appearanceMode == 1 → .light
  · appearanceMode == 2 → .dark
- @AppStorage("appearanceMode")를 읽어서 바인딩
- 변경 즉시 앱 전체에 반영

4. 디자인 시스템 준수
- Theme.Palette 컬러, Theme.mono/sans/serif 폰트 사용
- List 배경은 Theme.Palette.bg
- 셀/텍스트 스타일은 기존 View들과 일관성 유지

5. 접근성
- 모든 버튼/링크에 accessibilityLabel
- Dynamic Type 연계

⚠️ 건드리지 말 것:
- Services/, Models/, Resources/terms.json
- 기존 Features/Search, Detail, Bookmark, History, Onboarding의 로직 (import만 OK)

#Preview 매크로 포함 (PreviewTermService 사용)
논리 단위로 Conventional Commits 커밋. push/PR은 하지 마. 커밋까지만.
빌드 통과 확인.
```

### F 머지 후 남은 작업

- **E2E 통합 테스트 완료**: 설정 화면 포함 전체 플로우 재검증
- **배포 단계** (spec 밖): 앱 아이콘, 스크린샷, App Store Connect 등록, 개인정보 처리방침 페이지
