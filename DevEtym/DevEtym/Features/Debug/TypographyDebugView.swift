#if DEBUG
import SwiftUI

/// 타이포그래피 토큰·패밀리·사이즈를 한눈에 비교하는 디버그 뷰.
/// SearchView 의 HUD 탭으로 sheet 호출. 머지 전 제거.
struct TypographyDebugView: View {

    enum Family: String, CaseIterable, Identifiable {
        case system = "SF"
        case dmSans = "DM Sans"
        case dmMono = "DM Mono"
        case dmSerif = "DM Serif"
        var id: String { rawValue }
    }

    @State private var size: CGFloat = 15
    @State private var family: Family = .system
    @State private var weight: Font.Weight = .regular

    @Environment(\.dismiss) private var dismiss

    /// 한글·영문·혼합 비교용 샘플
    private let sampleKorean = "개발 용어의 어원과 작명 이유"
    private let sampleEnglish = "mutex semaphore daemon"
    private let sampleMixed = "// 개발 어원 mutex 검색"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    playgroundSection
                    Divider()
                    sideBySideSection
                    Divider()
                    tokenReferenceSection
                    Divider()
                    colorSamplesSection
                }
                .padding(20)
            }
            .background(Theme.Palette.bg)
            .navigationTitle("Typography Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
    }

    // MARK: - Playground (슬라이더로 즉시 조정)

    private var playgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Playground")

            Picker("Family", selection: $family) {
                ForEach(Family.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented)

            Picker("Weight", selection: $weight) {
                Text("Regular").tag(Font.Weight.regular)
                Text("Medium").tag(Font.Weight.medium)
                Text("Semibold").tag(Font.Weight.semibold)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("\(Int(size))pt")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 56, alignment: .leading)
                Slider(value: $size, in: 8...28, step: 1)
                    .tint(Theme.Palette.accent)
            }

            VStack(alignment: .leading, spacing: 10) {
                sampleLine(label: "한글", text: sampleKorean)
                sampleLine(label: "영문", text: sampleEnglish)
                sampleLine(label: "혼합", text: sampleMixed)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func sampleLine(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.Palette.textMuted)
            Text(text)
                .font(playgroundFont)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    private var playgroundFont: Font {
        switch family {
        case .system:
            return .system(size: size, weight: weight)
        case .dmSans:
            let w: Theme.SansWeight = (weight == .regular) ? .regular : .medium
            return Theme.sans(size, weight: w)
        case .dmMono:
            let w: Theme.MonoWeight = {
                switch weight {
                case .regular: return .regular
                case .medium, .semibold: return .medium
                default: return .light
                }
            }()
            return Theme.mono(size, weight: w)
        case .dmSerif:
            return Theme.serif(size)
        }
    }

    // MARK: - 같은 텍스트, 다른 패밀리·사이즈 (한글 메트릭 비교)

    private var sideBySideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Side-by-side · 한글 메트릭")
            Text("같은 사이즈에서 패밀리만 바꿔 한글 글리프 크기 비교")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textMuted)

            ForEach([13, 15, 17] as [CGFloat], id: \.self) { pt in
                sideBySideRow(pt: pt)
            }
        }
    }

    private func sideBySideRow(pt: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(pt))pt")
                .font(.caption)
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 4) {
                labeledSample("SF",      font: .system(size: pt))
                labeledSample("DM Sans", font: Theme.sans(pt))
                labeledSample("DM Mono", font: Theme.mono(pt))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func labeledSample(_ label: String, font: Font) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.Palette.textMuted)
                .frame(width: 64, alignment: .leading)
            Text("개발 어원 mutex 검색")
                .font(font)
                .foregroundStyle(Theme.Palette.text)
        }
    }

    // MARK: - 현재 Theme.Typography 토큰 전체

    private var tokenReferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Theme.Typography Tokens")

            Group {
                tokenRow("titleHero",        spec: "DM Serif 28 / largeTitle",  font: Theme.Typography.titleHero)
                tokenRow("titleTab",         spec: "DM Serif 20 / title2",     font: Theme.Typography.titleTab)
            }
            Group {
                tokenRow("bodyLarge",        spec: "SF .body (17)",            font: Theme.Typography.bodyLarge)
                tokenRow("body",             spec: "SF .body (17)",            font: Theme.Typography.body)
                tokenRow("bodySub",          spec: "SF .body (17)",            font: Theme.Typography.bodySub)
                tokenRow("bodyEmphasis",     spec: "SF .headline (17 sb)",     font: Theme.Typography.bodyEmphasis)
                tokenRow("bodyBlock",        spec: "SF .body (17)",            font: Theme.Typography.bodyBlock)
                tokenRow("bodyNotice",       spec: "SF .callout (16)",         font: Theme.Typography.bodyNotice)
                tokenRow("bodyPreview",      spec: "SF .body (17)",            font: Theme.Typography.bodyPreview)
                tokenRow("bodyPreviewSmall", spec: "SF .footnote (13)",        font: Theme.Typography.bodyPreviewSmall)
            }
            Group {
                tokenRow("codeHero",         spec: "DM Mono 20 medium",        font: Theme.Typography.codeHero)
                tokenRow("codeBody",         spec: "DM Mono 17 medium",        font: Theme.Typography.codeBody)
                tokenRow("codeInput",        spec: "DM Mono 17",               font: Theme.Typography.codeInput)
                tokenRow("codeValue",        spec: "DM Mono 15",               font: Theme.Typography.codeValue)
                tokenRow("badge",            spec: "DM Mono 11 medium",        font: Theme.Typography.badge)
            }
            Group {
                tokenRow("codeAction",       spec: "SF .callout medium (16)",  font: Theme.Typography.codeAction)
                tokenRow("sectionHeader",    spec: "SF .subheadline med (15)", font: Theme.Typography.sectionHeader)
                tokenRow("label",            spec: "SF .subheadline (15)",     font: Theme.Typography.label)
                tokenRow("caption",          spec: "SF .caption (12)",         font: Theme.Typography.caption)
            }
        }
    }

    private func tokenRow(_ name: String, spec: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.Palette.accent)
                Text(spec)
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            Text("개발 어원 mutex 검색")
                .font(font)
                .foregroundStyle(Theme.Palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - 컬러 토큰 on 다른 surface

    private var colorSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Colors · text/textDim/textMuted")
            Text("다크모드에서 같은 사이즈가 surface 마다 어떻게 보이는지")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textMuted)

            colorRow(bg: Theme.Palette.bg,       label: "bg")
            colorRow(bg: Theme.Palette.surface,  label: "surface")
            colorRow(bg: Theme.Palette.surface2, label: "surface2")
        }
    }

    private func colorRow(bg: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.Palette.textMuted)
            VStack(alignment: .leading, spacing: 4) {
                Text("text · 본문 텍스트 sample")
                    .foregroundStyle(Theme.Palette.text)
                Text("textDim · 보조 텍스트 sample")
                    .foregroundStyle(Theme.Palette.textDim)
                Text("textMuted · 캡션 텍스트 sample")
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .font(.system(.callout))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Palette.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - 헬퍼

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline))
            .foregroundStyle(Theme.Palette.text)
    }
}

#Preview {
    TypographyDebugView()
        .preferredColorScheme(.dark)
}
#endif
