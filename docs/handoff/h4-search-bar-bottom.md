# 핸드오프 H4 — 검색창 하단 재배치 (한 손 도달성)

작성 세션: 오케스트레이션 세션 2026-06-21. 실행: 별도 브랜치(예: `feat/search-bar-bottom-placement`).
정본 상태는 `ROADMAP.md` Next의 동일 항목. 디자인 결정은 이미 확정됨(아래).

## 문제 / 목적

상단 검색창이 엄지로 멀어 한 손 조작이 불편 → 검색 입력 지점을 화면 하단으로 내려 도달성 개선
(Safari iOS 15+ 하단 주소창 선례). 출시 하드 게이트는 아니나 첫인상에 영향.

## 이미 내려진 결정 (다시 논의하지 말 것)

- **A안 채택**: 하단 검색 + **하단 탭바 유지**. (상단 탭바로 옮기는 B안은 iOS 관례 이탈 비용 때문에 탈락.)
- **최근검색 칩을 검색필드 바로 위(하단)로** 정렬 — 칩이 엄지 존에 들어오고 입력 시 자동완성으로 자연 전환.
- 시안 보존: `docs/design/search-placement-mockup.html`.

## 실행 세션이 풀어야 할 것 (구현 설계는 위임 — 미리 답 박지 말 것)

레이아웃 자체는 `ios-ux-design` 에이전트와 `SearchView` 현 구조를 보고 결정하되, 아래 알려진 난점을 반드시 해결:
- ⓐ **자동완성 위로 펼침**(메신저식) — 현재는 필드 아래 `suggestionList`. 하단 배치 시 위로 펼쳐야 함.
- ⓑ **입력 시작 시 키보드 회피** — 하단 필드가 키보드에 가리지 않게.
- ⓒ **mini(13 mini 등) 바닥 2층 크롬 압박** — 하단탭바+검색필드 동시 노출 시 세로 압박. 입력 중 탭바 숨김 검토.

## 현재 구조 (출발점)

- `DevEtym/DevEtym/Features/Search/SearchView.swift` (223줄): 현재 `content`가
  `VStack { header → searchField → hintText → (suggestionList | recentSection+Spacer) }` 상단 정렬.
  `NavigationStack` + `path` 소유, `DetailView` push/replace 제어.
- `SearchViewModel.swift` (52줄): `query`, `suggestions`, `refreshRecent()`.
- 디자인 토큰(`Theme.Palette`, `typo*`) 재사용 — 새 색/폰트 만들지 말 것.

## 제약
- `TermServiceProtocol` 의존 규칙·`@MainActor`·MVVM 경계 유지.
- 다크모드 자동 대응, Dynamic Type 깨지지 않게.

## 완료 조건
- 검색필드가 하단, 최근검색 칩이 그 바로 위, 자동완성 위로 펼침, 키보드 회피 동작.
- 13 mini + 큰 Dynamic Type에서 크롬 압박/잘림 없음.
- 시안 A안과 일치. `#Preview` 갱신.

## 참조
- 시안: `docs/design/search-placement-mockup.html`
- 에이전트: `ios-ux-design`
- ROADMAP Next "[UI] 검색창 하단 재배치"
