import SwiftUI

/// 상세 화면
/// - keyword를 받아 TermResult에 따라 분기 표시
/// - source(번들/AI)에 따라 AI 생성 뱃지를 노출
/// - possibleTypo 시 추천 용어는 부모 NavigationStack의 path를 replace
struct DetailView: View {
    let keyword: String
    /// possibleTypo 추천 용어 탭 시 호출 (부모가 path.removeLast 후 append)
    var onSelectSuggestion: ((String) -> Void)?

    @Environment(\.termService) private var termService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DetailViewModel()

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                case .loaded(let result):
                    loadedView(result)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Palette.surface, for: .navigationBar)
        .onAppear {
            viewModel.termService = termService
            viewModel.load(keyword: keyword)
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("확인") {
                viewModel.errorMessage = nil
                dismiss()
            }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - 상태별 View

    private var loadingView: some View {
        VStack(spacing: 14) {
            Text(keyword)
                .font(Theme.mono(18, weight: .medium, relativeTo: .title3))
                .foregroundStyle(Theme.Palette.accent)
            ProgressView()
                .tint(Theme.Palette.accent)
            Text("어원을 분석하는 중...")
                .font(Theme.mono(10, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(keyword) 어원을 분석하는 중")
    }

    @ViewBuilder
    private func loadedView(_ result: TermResult) -> some View {
        switch result {
        case .found(let entry, let source):
            foundView(entry: entry, source: source)
        case .notDevTerm:
            notDevTermView
        case .possibleTypo(let suggestion):
            possibleTypoView(suggestion: suggestion)
        }
    }

    private func foundView(entry: TermEntry, source: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerBlock(entry: entry, source: source)
                    Divider().background(Theme.Palette.border)
                    sectionLabel("어원")
                    etymologyBlock(entry.etymology)
                    sectionLabel("왜 이 이름인가")
                    Text(entry.namingReason)
                        .font(Theme.sans(13, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.textDim)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    actionRow(entry: entry)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            reportButton(entry: entry)
        }
    }

    private func headerBlock(entry: TermEntry, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.keyword)
                .font(Theme.serif(28, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Palette.text)
            HStack(spacing: 6) {
                categoryBadge(entry.category)
                if source == "ai" {
                    aiBadge
                }
            }
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(Theme.sans(13, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Palette.textDim)
                    .padding(.top, 4)
            }
        }
    }

    private func categoryBadge(_ category: String) -> some View {
        Text(CategoryDisplay.formatted(category).uppercased())
            .font(Theme.mono(9, relativeTo: .caption2))
            .tracking(0.6)
            .foregroundStyle(Theme.Palette.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.Palette.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Theme.Palette.accent.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("카테고리 \(category)")
    }

    private var aiBadge: some View {
        Text("✦ AI 생성")
            .font(Theme.mono(9, relativeTo: .caption2))
            .tracking(0.6)
            .foregroundStyle(Theme.Palette.accentAI)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.Palette.accentAI.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Theme.Palette.accentAI.opacity(0.25), lineWidth: 1)
            )
            .accessibilityLabel("이 설명은 AI가 생성한 결과입니다")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.mono(9, relativeTo: .caption2))
            .tracking(1.2)
            .foregroundStyle(Theme.Palette.textMuted)
    }

    private func etymologyBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Theme.Palette.accent)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(Theme.sans(12, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.textDim)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(Theme.Palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionRow(entry: TermEntry) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.toggleBookmark()
            } label: {
                Label(viewModel.isBookmarked ? "북마크 해제" : "북마크",
                      systemImage: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Palette.accent)
            .background(Theme.Palette.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Palette.accent.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(viewModel.isBookmarked ? "북마크 해제" : "북마크 추가")

            ShareLink(item: shareText(entry: entry)) {
                Label("공유", systemImage: "square.and.arrow.up")
                    .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .foregroundStyle(Theme.Palette.textDim)
            .background(Theme.Palette.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("\(entry.keyword) 공유")
        }
        .padding(.top, 8)
    }

    private func shareText(entry: TermEntry) -> String {
        "\(entry.keyword)\n\n\(entry.summary)\n\n— DevEtym"
    }

    // MARK: - 비-결과 상태

    private var notDevTermView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
            Text("개발 용어를 검색해주세요")
                .font(Theme.sans(15, weight: .medium, relativeTo: .headline))
                .foregroundStyle(Theme.Palette.text)
            Button {
                dismiss()
            } label: {
                Text("검색으로 돌아가기")
                    .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .foregroundStyle(Theme.Palette.accent)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Palette.accent.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func possibleTypoView(suggestion: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Palette.accent)
                .accessibilityHidden(true)
            Text("\(suggestion)을(를) 찾으셨나요?")
                .font(Theme.sans(15, weight: .medium, relativeTo: .headline))
                .foregroundStyle(Theme.Palette.text)
            Button {
                onSelectSuggestion?(suggestion)
            } label: {
                Text(suggestion)
                    .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .foregroundStyle(Theme.Palette.bg)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.Palette.accent)
                    )
            }
            .accessibilityLabel("추천 용어 \(suggestion) 검색")
            Button("아니요, 돌아가기") { dismiss() }
                .font(Theme.mono(10, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 오류 제보

    @ViewBuilder
    private func reportButton(entry: TermEntry) -> some View {
        VStack(spacing: 0) {
            Divider().background(Theme.Palette.border)
            if let url = reportMailtoURL(entry: entry) {
                Link(destination: url) {
                    Label("이 설명이 잘못됐나요? 오류 제보하기", systemImage: "envelope")
                        .font(Theme.mono(10, relativeTo: .footnote))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                .padding(.vertical, 12)
                .accessibilityLabel("오류 제보 메일 보내기")
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.surface)
    }

    private func reportMailtoURL(entry: TermEntry) -> URL? {
        let subject = "[오류제보] \(entry.keyword)"
        let body = """
        ■ 용어: \(entry.keyword)
        ■ 요약: \(entry.summary)
        ■ 어원: \(entry.etymology)
        ■ 작명이유: \(entry.namingReason)
        ─────────────
        어떤 부분이 잘못되었나요?
        →
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

#Preview("found · DB") {
    NavigationStack {
        DetailView(keyword: "mutex")
            .environment(\.termService, PreviewTermService(defaultSource: "bundle"))
    }
    .preferredColorScheme(.dark)
}

#Preview("found · AI") {
    NavigationStack {
        DetailView(keyword: "harness")
            .environment(\.termService, PreviewTermService(defaultSource: "ai"))
    }
    .preferredColorScheme(.dark)
}

#Preview("notDevTerm") {
    NavigationStack {
        DetailView(keyword: "hello")
            .environment(\.termService, PreviewTermService(fetchResult: .notDevTerm))
    }
    .preferredColorScheme(.dark)
}

#Preview("possibleTypo") {
    NavigationStack {
        DetailView(keyword: "mutx")
            .environment(
                \.termService,
                PreviewTermService(fetchResult: .possibleTypo("mutex"))
            )
    }
    .preferredColorScheme(.dark)
}
