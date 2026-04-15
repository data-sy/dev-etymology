import SwiftUI

/// 히스토리 탭
/// - recentSearches(limit:)로 목록 조회
/// - 스와이프 삭제 / 전체 삭제 후 목록 즉시 재조회
struct HistoryView: View {
    @Environment(\.termService) private var termService
    @StateObject private var viewModel = HistoryViewModel()
    @State private var path = NavigationPath()
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("히스토리")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("전체 삭제") {
                            showClearConfirm = true
                        }
                        .disabled(viewModel.entries.isEmpty)
                    }
                }
                .navigationDestination(for: String.self) { keyword in
                    DetailView(keyword: keyword)
                }
                .confirmationDialog(
                    "모든 히스토리를 삭제하시겠습니까?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("전체 삭제", role: .destructive) {
                        viewModel.clearAll()
                    }
                    Button("취소", role: .cancel) {}
                }
        }
        .onAppear {
            viewModel.termService = termService
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.entries.isEmpty {
            emptyView
        } else {
            list
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("검색 기록이 없습니다")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(viewModel.entries, id: \.keyword) { entry in
                Button {
                    path.append(entry.keyword)
                } label: {
                    HStack {
                        Text(entry.keyword)
                        Spacer()
                        Text(entry.searchedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.delete(entry.keyword)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview("빈 상태") {
    HistoryView()
        .environment(\.termService, MockTermService())
}

#Preview("항목 있음") {
    HistoryView()
        .environment(
            \.termService,
            MockTermService(histories: [
                SearchHistory(keyword: "mutex"),
                SearchHistory(keyword: "deadlock"),
                SearchHistory(keyword: "semaphore")
            ])
        )
}
