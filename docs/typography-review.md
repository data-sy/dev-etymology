# DevEtym 타이포그래피 가독성 — 2차 리뷰 요청

## TL;DR
한국 개발자용 iOS 사전 앱 (SwiftUI, iOS 18+, 다크모드 기본). 사용자 피드백 "글자가 작다·연하다" 받고 4커밋으로 textMuted 대비 + 폰트 사이즈 조정했는데, 빌드 검증 마쳤음에도 사용자가 **여전히 작다고 느낌**. 폰트 패밀리 자체(DM Mono / DM Sans)가 SF 대비 x-height 가 작아서일 가능성. 더 키울지, 폰트 패밀리를 바꿀지, 다른 길이 있는지 의견 부탁.

---

## 프로젝트 컨텍스트
- **앱**: 개발 어원 사전 (DevEtym). 영문 개발 용어 (mutex, deadlock 등) 입력하면 한국어로 어원·작명 이유 설명.
- **타깃**: iOS 18+, SwiftUI, **다크모드 기본**.
- **디자인 의도**: 에디토리얼풍. 큰 serif 타이틀 (DM Serif Display) + 모노/산스 본문 (DM Mono / DM Sans).
- **사용자**: 한국 개발자.

## 폰트 패밀리
- **본문 sans**: DM Sans (Regular / Medium)
- **코드·라벨 mono**: DM Mono (Light / Regular / Medium)
- **타이틀 serif**: DM Serif Display (Regular / Italic)
- 모두 OFL, 번들 포함, Info.plist `UIAppFonts` 등록됨.
- `.custom(name, size:, relativeTo:)` 로 SwiftUI Dynamic Type 추종.

## 사용자 피드백 (원문)
> "글자 크기가 좀 작은 것 같아서. 글자 색도 연해서 잘 안 보이는 것 같아. 다크모드가 디폴트라 다크모드 기준이긴 해."

## 진단 (1차)
1. **textMuted 컬러**: `#666666` 다크 bg 위 3.45:1 → WCAG AA(4.5:1) 미달
2. **폰트 사이즈**: iOS 본문 표준 17pt 대비 -4pt (sans 13). 정보 밀집 화면(Detail의 어원·namingReason)에서 작게 체감

## 변경 (5커밋, main 위 리베이스 완료)

### 1. textMuted AA 통과 (`fix:`)
- 다크: `#666` → `#8A` (WCAG 5.04:1 on darkest surface)
- 라이트: `#888` → `#6B`

### 2. 본문 sans +2pt (`refactor:`)
- sans 13 → 15 (Detail namingReason / summary, Onboarding 서브타이틀)
- sans 12 → 14 (etymology 블록, 고지문, 라이선스)
- sans 14 → 16 (Settings 항목 라벨)
- 등

### 3. 라벨·뱃지 mono +1pt (`refactor:`)
- mono 9 → 10 (caption2: 카테고리·AI 뱃지, 섹션 라벨)
- mono 10 → 11 (footnote: 힌트·서브타이틀·empty·칩)
- mono 11 → 12 (medium footnote: 액션 버튼·AI 고지 강조)
- 카테고리·AI 뱃지 padding h7/v3 → h8/v4 (비례)

### 4. Theme.Typography 중앙화 (`refactor:`)
54개 호출부의 raw `Theme.sans/mono/serif()` 를 의미론적 토큰으로 치환. 추후 사이즈 조정은 Theme.swift 한 파일에서.

### 5. codeInput·codeBody +2pt (`refactor:`)
검색·북마크·히스토리 주요 요소(검색 입력필드, 리스트 용어명, CTA) 가 mono 13 으로 묶여 있어 사용자 체감 변화 부족. mono 13 → 15.

---

## 현재 Theme.Typography 토큰 (전체)

```swift
enum Typography {
    // 타이틀 (serif)
    static let titleHero        = Theme.serif(28, relativeTo: .largeTitle)
    static let titleTab         = Theme.serif(20, relativeTo: .title2)

    // 본문 (sans)
    static let bodyLarge        = Theme.sans(16, relativeTo: .body)            // Settings 항목 라벨
    static let body             = Theme.sans(15, relativeTo: .body)            // Detail 본문, Onboarding 서브
    static let bodySub          = Theme.sans(15, relativeTo: .subheadline)     // Detail summary
    static let bodyEmphasis     = Theme.sans(15, weight: .medium, relativeTo: .headline)  // 빈 상태 타이틀
    static let bodyBlock        = Theme.sans(14, relativeTo: .body)            // etymology 블록
    static let bodyNotice       = Theme.sans(14, relativeTo: .footnote)        // 고지문·OFL 본문
    static let bodyPreview      = Theme.sans(13, relativeTo: .caption)         // 자동완성 미리보기
    static let bodyPreviewSmall = Theme.sans(12, relativeTo: .caption)         // 북마크 미리보기

    // 코드 (mono, medium)
    static let codeHero         = Theme.mono(18, weight: .medium, relativeTo: .title3)     // 로딩 헤더
    static let codeBody         = Theme.mono(15, weight: .medium, relativeTo: .body)       // 리스트 용어명·CTA
    static let codeAction       = Theme.mono(12, weight: .medium, relativeTo: .footnote)   // 액션 버튼
    static let sectionHeader    = Theme.mono(11, weight: .medium, relativeTo: .caption2)   // Settings SECTION

    // 코드 (mono, regular)
    static let codeInput        = Theme.mono(15, relativeTo: .body)            // 검색 입력·히스토리 용어명
    static let codeValue        = Theme.mono(13, relativeTo: .footnote)        // Settings 정보값
    static let label            = Theme.mono(11, relativeTo: .footnote)        // 힌트·서브타이틀·empty·칩
    static let caption          = Theme.mono(10, relativeTo: .caption2)        // 섹션 라벨·뱃지·상대시간
}
```

## 컬러 토큰 (다크모드 기준)
```
bg        #0A0A0A   surface   #111111   surface2  #1A1A1A
text      #F0F0F0   17.38:1 on bg
textDim   #999999   6.96:1
textMuted #8A8A8A   5.74:1   ← 변경됨 (#666 → #8A)
border    
accent    #C8F060   (라임 그린)
accent2   
accentAI  (시안)
brand     
```

---

## 검증 결과 (사용자 피드백)
- **빌드 검증 OK**: 디버그 HUD 박아서 사용자 화면에 `v1284ff6 ▸ codeInput=15 codeBody=15 body=15 bodyLarge=16` 빨간 텍스트 표시 → 올바른 빌드 실행 중 입증.
- **사용자 응답**: HUD 는 보이지만 본문 텍스트가 **여전히 작다고 느낌**.

## 가설 (왜 여전히 작은가)

### A. DM 폰트 패밀리의 시각적 작음
DM Mono / DM Sans 의 **x-height 가 SF 대비 작음**. 같은 pt 라도 DM 15 ≈ SF 13~14 체감. iOS 본문 표준 17pt 와 -3~4pt 갭.

### B. 한글 가독성
DM 폰트는 영문용. 한글은 시스템 fallback 으로 Apple SD Gothic Neo 가 렌더되는데, 이때 **DM 의 baseline·line-height 에 한글이 맞춰지면서 한글이 더 작아 보일** 가능성.

### C. 정보 밀도
검색 홈에 너무 많은 텍스트 종류 (헤더 + 서브타이틀 + 입력 + 힌트 + 섹션 + 칩) 이 작은 사이즈로 빽빽함. 사이즈 외에 line-height·padding 도 영향.

### D. 사용자 기대치
사용자는 SF 17pt 본문에 익숙. 에디토리얼풍 디자인 자체가 정보 밀집 앱에는 안 맞을 수도.

---

## 검색 홈 화면 코드 (현재)

```swift
struct SearchView: View {
    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                Theme.Palette.bg.ignoresSafeArea()
                content
                #if DEBUG
                debugHUD
                #endif
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DevEtym")
                .font(Theme.Typography.titleTab)         // serif 20
                .foregroundStyle(Theme.Palette.text)
            Text("// 개발 용어 어원 사전")
                .font(Theme.Typography.label)            // mono 11
                .tracking(0.6)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textMuted)
            TextField(
                "",
                text: $viewModel.query,
                prompt: Text("mutex, semaphore, daemon...").foregroundColor(Theme.Palette.textMuted)
            )
                .font(Theme.Typography.codeInput)        // mono 15
                .foregroundStyle(Theme.Palette.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            // …
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.Palette.surface2)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.border, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var hintText: some View {
        Text("영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)")
            .font(Theme.Typography.label)                // mono 11
            .foregroundStyle(Theme.Palette.textMuted)
    }

    // 자동완성 결과 행
    Text(entry.keyword).font(Theme.Typography.codeBody)        // mono 15 medium
    Text(entry.summary).font(Theme.Typography.bodyPreview)     // sans 13

    // 섹션 라벨 (예: "최근 검색")
    Text(text.uppercased()).font(Theme.Typography.caption)     // mono 10
}
```

## Detail 화면 (정보 밀집 — 가장 사용자가 머무는 화면)

```swift
// 키워드 (대형)
Text(entry.keyword).font(Theme.Typography.titleHero)            // serif 28
// 카테고리 / AI 뱃지
Text(category).font(Theme.Typography.caption)                   // mono 10
// summary (한 줄 요약)
Text(entry.summary).font(Theme.Typography.bodySub)              // sans 15
// 어원 (가장 긴 본문)
Text(text).font(Theme.Typography.bodyBlock)                     // sans 14
// "왜 이 이름인가" 본문
Text(entry.namingReason).font(Theme.Typography.body)            // sans 15
// 액션 버튼 (북마크·공유)
Label(...).font(Theme.Typography.codeAction)                    // mono 12 medium
```

---

## 리뷰 받고 싶은 것

1. **사이즈 부족 진단이 맞나?** mono 15 / sans 15 가 한국어 + DM 패밀리에서 본문으로는 너무 작은가?
2. **폰트 패밀리 결정**: DM 계열을 유지할지, 본문만 SF 로 바꿀지 (에디토리얼 헤더는 DM Serif 유지). 트레이드오프?
3. **얼만큼 더 키울지**: codeInput/codeBody mono 15 → 17, body sans 15 → 17, bodyLarge 16 → 18 가 합리적인가? 아니면 시스템 dynamic type preset (`.body`, `.callout`) 으로 가는 게 나은가?
4. **놓친 가설**: x-height·한글 fallback·line-height 외에 더 의심할 만한 게 있나?
5. **다크모드 특유 이슈**: 다크에서 같은 사이즈가 라이트보다 작게 느껴지는 효과 (anti-aliasing, contrast) 가 작용하나? 보정 필요?

## 참고 첨부
- 현재 검색 홈 스크린샷: `debug_hud.png` (디버그 HUD 포함)
- 이전(rebase 전) 검색 홈: `typo-scale.png`
- Repo: `/Users/owner/devetym-ui-readability` (브랜치 `feat/typography-contrast-pass`)
- 커밋 히스토리: `git log --oneline origin/main..HEAD`
