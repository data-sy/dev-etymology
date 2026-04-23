import SwiftUI

/// 북마크 탭
/// - bookmarkedTerms()로 목록 조회, 스와이프 → 북마크 해제
/// - 항목 탭 → DetailView push (자체 NavigationStack 소유)
struct BookmarkView: View {
    @Environment(\.termService) private var termService
    @StateObject private var viewModel = BookmarkViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { keyword in
                DetailView(keyword: keyword)
            }
        }
        .onAppear {
            viewModel.termService = termService
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.terms.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("북마크")
                .font(Theme.serif(20, relativeTo: .title2))
                .foregroundStyle(Theme.Palette.text)
            Text("// 저장한 용어")
                .font(Theme.mono(11, relativeTo: .footnote))
                .tracking(0.6)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("북마크, 저장한 용어")
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
            Text("아직 저장한 용어가 없어요.\n용어 검색 후 북마크해보세요.")
                .multilineTextAlignment(.center)
                .font(Theme.mono(11, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textMuted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(0.6)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.terms, id: \.keyword) { term in
                    Button {
                        path.append(term.keyword)
                    } label: {
                        bookmarkRow(term: term)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(term.keyword), \(previewText(for: term))")
                    .accessibilityHint("탭하여 상세 보기")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeBookmark(term)
                        } label: {
                            Label("삭제", systemImage: "bookmark.slash")
                        }
                        .accessibilityLabel("\(term.keyword) 북마크 해제")
                    }
                    Divider().background(Theme.Palette.border)
                }
            }
        }
    }

    private func bookmarkRow(term: Term) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(term.keyword)
                    .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.text)
                Text(previewText(for: term))
                    .font(Theme.sans(12, relativeTo: .caption))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewText(for term: Term) -> String {
        if !term.summary.isEmpty { return term.summary }
        return term.aliases.first ?? ""
    }
}

#Preview("빈 상태") {
    BookmarkView()
        .environment(\.termService, PreviewTermService())
        .preferredColorScheme(.dark)
}

#Preview("항목 있음") {
    BookmarkView()
        .environment(
            \.termService,
            {
                let mock = PreviewTermService()
                for entry in PreviewSamples.entries {
                    _ = try? mock.toggleBookmark(for: entry)
                }
                return mock
            }()
        )
        .preferredColorScheme(.dark)
}
