# CLAUDE.md — 개발 어원 사전 (DevEtym)

## 프로젝트 개요

개발 용어의 어원과 작명 이유를 한국어로 설명하는 iOS 사전 앱.
- 앱 표시 이름: 개발 어원 사전
- 번들 ID: com.robin.devetym
- 플랫폼: iOS 17+, SwiftUI
- 최소 배포 타겟: iOS 17.0

## 기술 스택

- UI: SwiftUI
- 데이터: SwiftData
- AI 연동: Claude API (Anthropic), URLSession
- 번들 DB: Resources/terms.json
- 테스트: XCTest + Swift Testing

## 프로젝트 구조

```
DevEtym/
├── App/
│   ├── DevEtymApp.swift
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
│   ├── TermService.swift       # 오케스트레이터 (DB → 캐시 → AI, autocomplete 포함)
│   ├── BundleDBService.swift   # 번들 JSON 검색 (keyword + aliases)
│   └── ClaudeAPIService.swift  # Claude API 호출
├── Utils/
│   └── Constants.swift         # 제보 이메일 등 상수
├── Resources/
│   └── terms.json
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
[View] ← [ViewModel] ← [TermService]
                            ├─ BundleDBService (terms.json, 메모리)
                            ├─ SwiftData (Term, 디스크 캐시)
                            └─ ClaudeAPIService (네트워크)
```

### 의존성 규칙
- **ViewModel → TermServiceProtocol만 의존** (BundleDBService 직접 참조 금지)
- TermService 내부에서 BundleDBService, ClaudeAPIService 조합
- autocomplete도 TermServiceProtocol을 통해 호출

### SwiftData 저장 시점 (lazy 전략)
- AI 응답 수신 시 → Term으로 저장 (source: "ai", aliases 포함)
- 북마크 시 → 번들 용어도 이 시점에 Term으로 저장 (source: "bundle", aliases 포함)
- 번들 DB 용어는 검색만으로는 SwiftData에 저장하지 않음
- SearchHistory는 검색 성공 시에만 저장

### TermEntry ↔ Term 변환 규칙
- 변환 시 aliases를 반드시 포함할 것 (데이터 소실 방지)
- keyword, aliases, summary, etymology, namingReason 모두 보존

### 검색 결과 분기 (TermResult)
- `.found(TermEntry)` → 정상 결과 표시
- `.notDevTerm` → "개발 용어를 검색해주세요" 안내
- `.possibleTypo(String)` → "{suggestion}을(를) 찾으셨나요?" 안내

## 코딩 규칙

- 언어: Swift 5.9+, async/await 사용
- 아키텍처: MVVM. View는 UI만, 로직은 ViewModel
- SwiftData: @Model 클래스에 비즈니스 로직 넣지 말 것
- 에러 처리: 모든 throws 함수는 호출부에서 do-catch 처리
- 주석: 한국어로 작성
- 네이밍: 변수/함수는 camelCase, 타입은 PascalCase
- Preview: 모든 View에 #Preview 매크로 포함
- 새 Service 작성 시 Protocol 추상화 필수

## 절대 하지 말 것

- Force unwrap (!) 사용 금지 — guard let 또는 if let 사용
- Main thread 외에서 UI 업데이트 금지
- API 키를 코드에 하드코딩 금지 — Info.plist 또는 환경변수 사용
- 거대한 단일 파일 — 역할별로 파일 분리
- 검색 실패 시 SearchHistory 저장 금지
- ViewModel에서 BundleDBService 직접 참조 금지 — TermServiceProtocol을 통할 것
- TermEntry → Term 변환 시 aliases 누락 금지

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
