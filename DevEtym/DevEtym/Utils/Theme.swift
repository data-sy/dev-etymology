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
    /// 호출부는 `Theme.sans/mono/serif`를 직접 부르지 말고 아래 토큰만 사용.
    /// 사이즈·weight·Dynamic Type 스케일을 여기서만 조정하면 전 화면에 반영된다.
    enum Typography {

        // MARK: 타이틀 (serif)

        /// 용어명 대형 / Onboarding 타이틀 (serif 28 · largeTitle)
        static let titleHero        = Theme.serif(28, relativeTo: .largeTitle)
        /// 탭 헤더 (serif 20 · title2) — 검색·북마크·히스토리
        static let titleTab         = Theme.serif(20, relativeTo: .title2)

        // MARK: 본문 (sans)

        /// Settings 항목 라벨 (sans 16)
        static let bodyLarge        = Theme.sans(16, relativeTo: .body)
        /// 일반 본문 (sans 15) — Detail namingReason, Onboarding 서브타이틀
        static let body             = Theme.sans(15, relativeTo: .body)
        /// Detail summary 전용 (sans 15, subheadline 스케일)
        static let bodySub          = Theme.sans(15, relativeTo: .subheadline)
        /// 빈 상태·안내 타이틀 (sans 15 medium · headline)
        static let bodyEmphasis     = Theme.sans(15, weight: .medium, relativeTo: .headline)
        /// 강조 블록 내 본문 (sans 14) — Detail etymology 블록
        static let bodyBlock        = Theme.sans(14, relativeTo: .body)
        /// 고지문·OFL 본문 (sans 14 · footnote)
        static let bodyNotice       = Theme.sans(14, relativeTo: .footnote)
        /// 자동완성 한 줄 미리보기 (sans 13 · caption)
        static let bodyPreview      = Theme.sans(13, relativeTo: .caption)
        /// 북마크 리스트 한 줄 미리보기 (sans 12 · caption)
        static let bodyPreviewSmall = Theme.sans(12, relativeTo: .caption)

        // MARK: 코드·모노 (강조)

        /// 로딩 시 용어명 헤더 (mono 18 medium · title3)
        static let codeHero         = Theme.mono(18, weight: .medium, relativeTo: .title3)
        /// 리스트 행 용어명·CTA·라이선스 타이틀 (mono 15 medium · body)
        static let codeBody         = Theme.mono(15, weight: .medium, relativeTo: .body)
        /// 액션 버튼·강조 라벨 (mono 12 medium · footnote) — 북마크·공유·AI 생성 고지
        static let codeAction       = Theme.mono(12, weight: .medium, relativeTo: .footnote)
        /// Settings SECTION 헤더 (mono 11 medium · caption2)
        static let sectionHeader    = Theme.mono(11, weight: .medium, relativeTo: .caption2)

        // MARK: 코드·모노 (일반)

        /// 검색 입력필드·히스토리 행 용어명 (mono 15 · body)
        static let codeInput        = Theme.mono(15, relativeTo: .body)
        /// Settings 정보 행 값 (mono 13 · footnote)
        static let codeValue        = Theme.mono(13, relativeTo: .footnote)
        /// 힌트·서브타이틀·empty·칩 (mono 11 · footnote)
        static let label            = Theme.mono(11, relativeTo: .footnote)
        /// 섹션 라벨·뱃지·상대시간·보조 버튼 (mono 10 · caption2)
        static let caption          = Theme.mono(10, relativeTo: .caption2)
    }
}
