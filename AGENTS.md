# AGENTS.md — DevEtym 멀티 에이전트 작업 분배

> Git worktree를 사용해 각 에이전트가 독립 브랜치에서 작업.
> Phase 1 완료 후 멀티 에이전트 작업 시작.

---

## 전제 조건

- Phase 1 완료 후 멀티 에이전트 작업 시작
- 각 에이전트는 독립적인 git worktree에서 작업
- 에이전트 간 의존성 없는 작업만 병렬 처리

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
Agent B (UI)        ← MockTermService만 의존 (BundleDBService 직접 참조 금지)
Agent C (Bundle DB) ← 독립 작업
```

> **핵심**: UI 레이어의 모든 ViewModel은 TermServiceProtocol에만 의존한다.
> 자동완성(autocomplete)도 TermServiceProtocol을 통해 호출한다.
> Agent B는 MockTermService 하나만 구현하면 모든 UI를 독립적으로 개발할 수 있다.

---

## 에이전트 작업 분배

### Agent A — 서비스 레이어 (feat/services)

**담당 파일:**
- Services/BundleDBService.swift
- Services/ClaudeAPIService.swift
- Services/TermService.swift
- Models/TermEntry.swift
- Models/TermResult.swift
- Models/AIErrorResponse.swift
- Tests/TermServiceTests.swift
- Tests/BundleDBServiceTests.swift
- Tests/ClaudeAPIServiceTests.swift
- Tests/Mocks/MockBundleDBService.swift
- Tests/Mocks/MockClaudeAPIService.swift

**작업 지시:**
```
spec.md의 Phase 2를 구현하세요.

구현 순서:
1. TermEntry (aliases 필드 포함), TermResult, AIErrorResponse 모델 정의
2. BundleDBService: keyword + aliases 대소문자 무시 매칭 + autocomplete
3. ClaudeAPIService: 시스템 프롬프트에 error/suggestion 응답 구조 포함
4. TermService: 오케스트레이션 (Bundle → SwiftData 캐시 → AI 폴백)
   - TermServiceProtocol에 fetch + autocomplete 모두 포함
   - 입력 정규화 (trim + lowercase)
   - AI 오류 응답 분기 처리 (NOT_DEV_TERM, POSSIBLE_TYPO)
   - SearchHistory는 성공 시에만 저장
   - SwiftData 저장은 lazy 전략 (AI 응답 시 캐시, 북마크 시 번들 용어 저장)
   - Term 저장 시 aliases 반드시 포함

각 Service는 Protocol로 추상화하세요.
모든 Service에 대응하는 테스트를 작성하세요.
AI 오류 응답 분기 테스트를 반드시 포함하세요.
Phase 2 완료 조건을 충족하면 작업을 종료하세요.
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
- Utils/Constants.swift
- Tests/Mocks/MockTermService.swift

**작업 지시:**
```
spec.md의 Phase 3을 구현하세요.

⚠️ 중요: 모든 ViewModel은 TermServiceProtocol에만 의존하세요.
BundleDBService, ClaudeAPIService를 직접 import하거나 참조하지 마세요.
자동완성(autocomplete)도 TermServiceProtocol.autocomplete(prefix:)를 통해 호출하세요.

MockTermService 구현 (Tests/Mocks/MockTermService.swift):
- TermServiceProtocol을 준수
- fetch(keyword:) → 미리 정의된 TermResult 반환
- autocomplete(prefix:) → 미리 정의된 [TermEntry] 반환
- .notDevTerm, .possibleTypo 케이스도 Mock 데이터로 테스트 가능하게

주요 구현 사항:
1. SearchView
   - 검색창 하단 안내 문구: "영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)"
   - 타이핑 중 자동완성 (TermServiceProtocol.autocomplete 사용)
   - 최근 검색 칩 (SearchHistory 최근 5개)
2. DetailView
   - TermResult 분기 처리: .found / .notDevTerm / .possibleTypo
   - .found 시 작명 이유 본문을 ScrollView로 감싸 긴 텍스트 대응
   - .possibleTypo 시 추천 용어 탭으로 재검색
   - 북마크 버튼 (lazy 저장: 번들 용어도 이 시점에 SwiftData 저장, aliases 포함)
   - 하단 오류 제보 mailto (용어 정보 자동 채움)
3. BookmarkView: isBookmarked == true 쿼리, 스와이프 해제
4. HistoryView: 최근순 정렬, 스와이프 삭제, 전체 삭제
5. OnboardingView: AI 생성 고지 포함, AppStorage 플래그

Constants.swift에 제보 이메일(devetym@gmail.com) 등 상수 정의.
모든 View에 #Preview 매크로를 포함하세요.
Phase 3 완료 조건을 충족하면 작업을 종료하세요.
```

### Agent C — 번들 DB 생성 (feat/bundle-db)

**담당 파일:**
- Resources/terms.json
- Scripts/generate_db.py

**작업 지시:**
```
terms.json에 들어갈 초기 200개 용어를 생성하세요.
spec.md의 terms.json 스키마를 따르세요.
각 용어에 반드시 aliases 필드를 포함하세요.

aliases 규칙:
- 한글 표기 (예: "뮤텍스", "제이피에이")
- 풀네임 (예: "mutual exclusion", "java persistence api")
- 대소문자 변형은 검색 로직에서 처리하므로 aliases에 중복 불필요

카테고리별 분배:
- 동시성/병렬: mutex, semaphore, deadlock, race condition 등 (30개)
- 자료구조: stack, queue, heap, tree, graph 등 (30개)
- 네트워크: socket, handshake, latency, payload, DNS 등 (30개)
- DB: index, transaction, schema, shard, cursor 등 (30개)
- 패턴/아키텍처: singleton, factory, observer, MVC 등 (30개)
- 기타 핵심: bug, cache, compile, debug, daemon 등 (50개)

Scripts/generate_db.py는 Claude API를 호출해 배치 생성하는 스크립트입니다.
생성된 JSON은 aliases 포함 여부를 검증하세요.
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
- [ ] ViewModel 초기화에서 MockTermService → TermService 변경
- [ ] 전체 빌드 + 테스트 통과 확인

---

## CodeRabbit PR 리뷰 설정

각 브랜치 → main PR 생성 시 CodeRabbit이 자동 리뷰.

리뷰 포인트:
- Force unwrap 사용 여부
- Main thread UI 업데이트 위반
- 테스트 커버리지
- CLAUDE.md 코딩 규칙 준수
- aliases 필드 누락 여부 (terms.json, Term 모델)
- TermResult 분기 처리 누락 여부
- SearchHistory 저장 시점 규칙 위반 여부
- ViewModel에서 BundleDBService 직접 참조 여부 (금지)
- TermEntry → Term 변환 시 aliases 보존 여부
