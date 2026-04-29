# DevEtym Roadmap

이번 PR (`feat/typography-contrast-pass`) 에서 다루지 않았거나 의도적으로 미룬 항목.
새 항목 추가 시 한 줄 요약 + 배경 + 후보 액션 형식 유지.

---

## 후속 디자인 패스 (UI Polish)

이번 디자인 리뷰에서 잡힌 다크모드 시각 이슈. 본문 가독성과 직접 연관 없어 차후 라운드로 미룸.

### 헤더의 경계 부재 (다크모드)
- **증상**: 검색·북마크·히스토리 탭 상단 `serif 20 타이틀 + // 한글 subtitle` 조합이 검은 배경에 떠 있는 느낌. 라이트모드에선 자연스러움.
- **후보 액션**:
  - 헤더 하단 1px `Theme.Palette.border` divider
  - 좌측 accent 라인 (4px) 으로 anchor
  - serif 사이즈 한 단 상향 (20 → 22)
- **영향**: SearchView / BookmarkView / HistoryView 의 `header` 컴포넌트.

### 섹션 라벨 인식성 (다크모드)
- **증상**: "최근 검색" / "자동완성" / Detail 의 "어원" / "왜 이 이름인가" 가 caps mono 12 + textMuted 라 다크에서 약하게 보임. Settings 의 `sectionHeader` 는 accent 색이라 명확한데, 일반 sectionLabel 은 textMuted 라 위계가 약함.
- **후보 액션**:
  - 라벨 색을 textMuted → text 또는 textDim 으로 (위계 강화)
  - 라벨 옆 짧은 accent stroke
  - 일관성: 전 화면의 sectionLabel 을 Settings 의 sectionHeader 패턴 (accent 색) 으로 통일
- **영향**: SearchView / DetailView 의 `sectionLabel` 헬퍼, 그리고 `Theme.Typography.caption` 사용처.

### 라이트모드 폴리시
- **증상**: 이번 패스는 다크 우선이라 라이트모드는 fallback 수준. 세부 컬러·border 강도가 라이트에서 어색할 수 있음.
- **후보 액션**: 라이트모드 전용 검수 한 차례. textMuted 라이트 #6B (이번에 AA 통과시킴) 외에 surface/border 라이트 값 재검토.

---

## 보류한 결정 (Deferred Decisions)

이번 PR 에서 적용 안 한 디자인 리뷰 권고. 채택 시점·방식 미정.

### accent 변형값 (disabled / pressed)
- **컨텍스트**: 디자인 리뷰가 `accent #C8F060` 의 다크모드 강도 완화용 변형값 권고:
  - disabled: `#A8C850` (한 단 어둡게)
  - pressed: `#DCFF7A` (한 단 밝게)
- **미적용 이유**: 현재 호출부에 변형 색이 필요한 상태 없음. dead code 안 만듦.
- **재검토 트리거**: 버튼에 `.disabled(...)` 로직 들어가거나 인터랙션 피드백 더 필요해질 때.

### accent fill 강도 미세 조정
- **컨텍스트**: 카테고리·AI 뱃지 fill `opacity 0.08 → 0.12` 로 올림. TabBar 의 accent fill 은 그대로 유지 (디자인 리뷰가 약하게 권고).
- **재검토 트리거**: TabBar 시각이 너무 강하다는 사용자 피드백 들어오면 `accent.opacity(0.85)` 또는 라벨 색만 textDim 으로.

---

## 유지 보수 도구

### TypographyDebugView 활용
- **위치**: `DevEtym/Features/Debug/TypographyDebugView.swift` — `#if DEBUG` 게이트 (Release 빌드 영향 없음)
- **호출**: 현재 SearchView 디버그 HUD 가 머지 전에 제거되므로, 다음 라운드에 다시 토큰 튜닝하려면 임시로 HUD 복귀 또는 SettingsView 에 `#if DEBUG` 진입점 추가 필요.
- **기능**:
  - Playground: 슬라이더로 size 8~28pt, family (SF / DM Sans / DM Mono / DM Serif), weight 즉시 조정
  - Side-by-side: 같은 사이즈에서 패밀리만 바꿔 한글 메트릭 비교
  - Token reference: 현재 정의된 19개 토큰 시각 확인
  - Color samples: bg / surface / surface2 위 text / textDim / textMuted

### Theme.Typography 토큰 추가 시
- 폰트만 등록하면 안 됨 — `TypographyModifiers.swift` 에 대응 `.typoX()` 도 추가해서 lineSpacing/tracking 까지 묶을 것
- 호출부는 `.typoX()` 만 사용. raw `.font(Theme.Typography.X)` 직접 호출 금지 (디자인 시스템 단일 진입점 보장)

---

## 디자인 시스템 다음 단계 (향후 고려)

이번 PR 범위 밖. 시스템 성숙도 올리는 후속 단계.

- **컴포넌트 토큰화**: 현재는 폰트/컬러/스페이싱이 토큰. 버튼·뱃지·칩 같은 컴포넌트 자체를 재사용 가능한 View 로 추출 (예: `BadgeView(category:)`, `ChipView(text:)`).
- **모션 토큰**: 현재 트랜지션·애니메이션 일관성 없음. duration / easing 토큰화.
- **접근성 감사**: VoiceOver 라벨 누락·중복 검사, Dynamic Type extra-large 까지 깨지지 않는지.
