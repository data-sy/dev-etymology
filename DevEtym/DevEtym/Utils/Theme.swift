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
}
