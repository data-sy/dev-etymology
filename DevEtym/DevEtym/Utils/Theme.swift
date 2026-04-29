import SwiftUI

/// 디자인 시스템 진입점
/// - 컬러: Asset Catalog의 Theme namespace에 등록된 색상 토큰
/// - 폰트: DM Sans / DM Mono / DM Serif Display, Dynamic Type 연계
///
/// 폰트 파일이 번들에 포함되지 않은 환경에서는 SwiftUI가 시스템 기본 폰트로
/// fallback하므로 빌드/런타임에 영향이 없다.
enum Theme {

    // MARK: - Color tokens

    enum Palette {
        static let bg        = Color("Theme/bg")
        static let surface   = Color("Theme/surface")
        static let surface2  = Color("Theme/surface2")
        static let border    = Color("Theme/border")
        static let accent    = Color("Theme/accent")
        static let accent2   = Color("Theme/accent2")
        static let accentAI  = Color("Theme/accentAI")
        static let brand     = Color("Theme/brand")
        static let text      = Color("Theme/text")
        static let textDim   = Color("Theme/textDim")
        static let textMuted = Color("Theme/textMuted")
    }

    // MARK: - Font names (Resources/Fonts에 포함된 파일 PostScript 이름)

    enum FontName {
        static let sansRegular = "DMSans-Regular"
        static let sansMedium  = "DMSans-Medium"

        static let monoLight   = "DMMono-Light"
        static let monoRegular = "DMMono-Regular"
        static let monoMedium  = "DMMono-Medium"

        static let serif        = "DMSerifDisplay-Regular"
        static let serifItalic  = "DMSerifDisplay-Italic"
    }

    // MARK: - Font helpers (Dynamic Type 연계)

    /// 본문용 DM Sans (relativeTo:로 Dynamic Type 추종)
    static func sans(_ size: CGFloat,
                     weight: SansWeight = .regular,
                     relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .regular: name = FontName.sansRegular
        case .medium:  name = FontName.sansMedium
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// 코드/라벨/칩용 DM Mono
    static func mono(_ size: CGFloat,
                     weight: MonoWeight = .regular,
                     relativeTo style: Font.TextStyle = .footnote) -> Font {
        let name: String
        switch weight {
        case .light:   name = FontName.monoLight
        case .regular: name = FontName.monoRegular
        case .medium:  name = FontName.monoMedium
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// 용어명·섹션 타이틀용 DM Serif Display
    static func serif(_ size: CGFloat,
                      italic: Bool = false,
                      relativeTo style: Font.TextStyle = .title) -> Font {
        let name = italic ? FontName.serifItalic : FontName.serif
        return .custom(name, size: size, relativeTo: style)
    }

    enum SansWeight { case regular, medium }
    enum MonoWeight { case light, regular, medium }

    // MARK: - Typography (의미론적 폰트 토큰)

    /// 화면에서 실제로 쓰는 폰트 토큰의 중앙 저장소.
    ///
    /// 폰트 패밀리 선택 원칙
    /// - DM Serif Display: 디자인 시그니처. 짧은 헤더에만.
    /// - DM Mono: 영문 단독 텍스트(키워드·코드·고정폭 값·영문 뱃지) 한정.
    /// - 시스템 폰트(SF): 한글 비중이 큰 본문·라벨. 한글 fallback 메트릭 정상화.
    ///   커스텀 폰트의 metric 박스에 한글이 끼워 맞춰지면 시각적으로 작게 렌더되는 것을 회피.
    enum Typography {

        // MARK: 타이틀 (DM Serif — 디자인 정체성)

        /// 용어명 대형 / Onboarding 타이틀 (serif 28 · largeTitle)
        static let titleHero        = Theme.serif(28, relativeTo: .largeTitle)
        /// 탭 헤더 (serif 20 · title2) — 검색·북마크·히스토리
        static let titleTab         = Theme.serif(20, relativeTo: .title2)

        // MARK: 본문 (시스템 폰트 — HIG body 17pt 최소 보장)

        /// Settings 항목 라벨 (body 17pt)
        static let bodyLarge        = Font.system(.body)
        /// 일반 본문 — Detail namingReason, Onboarding 서브타이틀 (body 17pt)
        static let body             = Font.system(.body)
        /// Detail summary 전용 (body 17pt)
        static let bodySub          = Font.system(.body)
        /// 빈 상태·안내 타이틀 (headline 17pt semibold)
        static let bodyEmphasis     = Font.system(.headline)
        /// 강조 블록 내 본문 — Detail etymology(가장 길게 흐르는 본문) (body 17pt)
        static let bodyBlock        = Font.system(.body)
        /// 고지문·OFL 본문 (callout 16pt)
        static let bodyNotice       = Font.system(.callout)
        /// 자동완성 한 줄 미리보기 (body 17pt)
        static let bodyPreview      = Font.system(.body)
        /// 북마크 리스트 한 줄 미리보기 (footnote 13pt)
        static let bodyPreviewSmall = Font.system(.footnote)

        // MARK: 영문 코드 (DM Mono — 키워드·고정폭 값·영문 뱃지)

        /// 로딩 시 용어명 헤더 (mono 20 medium · title3)
        static let codeHero         = Theme.mono(20, weight: .medium, relativeTo: .title3)
        /// 리스트 행 영문 용어명 (mono 17 medium · body)
        static let codeBody         = Theme.mono(17, weight: .medium, relativeTo: .body)
        /// 검색 입력필드·히스토리 행 영문 키워드 (mono 17 · body)
        static let codeInput        = Theme.mono(17, relativeTo: .body)
        /// Settings 정보 행 값(버전·빌드 번호) (mono 15 · footnote)
        static let codeValue        = Theme.mono(15, relativeTo: .footnote)
        /// 카테고리·AI 뱃지(영문 라벨) (mono 11 medium · caption2)
        static let badge            = Theme.mono(11, weight: .medium, relativeTo: .caption2)

        // MARK: 한글 라벨 (시스템 폰트)

        /// 액션 버튼·강조 라벨 — 북마크·공유·AI 생성 고지 (callout 16pt medium)
        static let codeAction       = Font.system(.callout, weight: .medium)
        /// Settings SECTION 헤더 (subheadline 15pt medium)
        static let sectionHeader    = Font.system(.subheadline, weight: .medium)
        /// 힌트·서브타이틀·empty·칩 (subheadline 15pt)
        static let label            = Font.system(.subheadline)
        /// 섹션 라벨·상대시간·보조 버튼 (caption 12pt)
        static let caption          = Font.system(.caption)
    }
}
