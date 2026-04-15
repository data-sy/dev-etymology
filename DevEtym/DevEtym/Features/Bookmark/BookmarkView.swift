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
            content
                .navigationTitle("북마크")
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
        if viewModel.terms.isEmpty {
            emptyView
        } else {
            list
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("북마크한 용어가 없습니다")
                .font(.headline)
            Text("상세 화면에서 북마크 버튼을 눌러 저장해보세요")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var list: some View {
        List {
            ForEach(viewModel.terms, id: \.keyword) { term in
                Button {
                    path.append(term.keyword)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.keyword).font(.body)
                        Text(term.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.removeBookmark(term)
                    } label: {
                        Label("삭제", systemImage: "bookmark.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview("빈 상태") {
    BookmarkView()
        .environment(\.termService, MockTermService())
}

#Preview("항목 있음") {
    BookmarkView()
        .environment(
            \.termService,
            {
                let mock = MockTermService()
                for entry in MockTermService.sampleEntries {
                    _ = try? mock.toggleBookmark(for: entry)
                }
                return mock
            }()
        )
}
