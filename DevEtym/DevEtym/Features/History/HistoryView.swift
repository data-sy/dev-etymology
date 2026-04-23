import SwiftUI

/// 히스토리 탭
/// - recentSearches(limit:)로 목록 조회
/// - 스와이프 삭제 / 전체 삭제 후 목록 즉시 재조회
struct HistoryView: View {
    @Environment(\.termService) private var termService
    @StateObject private var viewModel = HistoryViewModel()
    @State private var path = NavigationPath()
    @State private var showClearConfirm = false

    /// 한국어 로케일 상대 시간 포매터 — "방금 전 / 1시간 전 / 어제 / 3일 전" 형식
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .full
        return f
    }()

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
            .confirmationDialog(
                "모든 히스토리를 삭제하시겠습니까?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("전체 삭제", role: .destructive) { viewModel.clearAll() }
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
        VStack(alignment: .leading, spacing: 16) {
            header
            if viewModel.entries.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("히스토리")
                    .font(Theme.serif(20, relativeTo: .title2))
                    .foregroundStyle(Theme.Palette.text)
                Text("// 최근 검색 기록")
                    .font(Theme.mono(11, relativeTo: .footnote))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("히스토리, 최근 검색 기록")
            Spacer()
            if !viewModel.entries.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Text("전체 삭제")
                        .font(Theme.mono(10, relativeTo: .caption2))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.Palette.border, lineWidth: 1)
                        )
                }
                .accessibilityLabel("히스토리 전체 삭제")
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
            Text("검색 기록이 없습니다")
                .font(Theme.mono(11, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(0.6)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.entries, id: \.keyword) { entry in
                    Button {
                        path.append(entry.keyword)
                    } label: {
                        historyRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.keyword), \(relativeText(for: entry.searchedAt))")
                    .accessibilityHint("탭하여 다시 검색")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.delete(entry.keyword)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .accessibilityLabel("\(entry.keyword) 검색 기록 삭제")
                    }
                    Divider().background(Theme.Palette.border)
                }
            }
        }
    }

    private func historyRow(entry: SearchHistory) -> some View {
        HStack {
            Text(entry.keyword)
                .font(Theme.mono(13, relativeTo: .body))
                .foregroundStyle(Theme.Palette.textDim)
            Spacer()
            Text(relativeText(for: entry.searchedAt))
                .font(Theme.mono(10, relativeTo: .caption2))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relativeText(for date: Date) -> String {
        // 1분 미만은 "방금 전"으로 표시
        if Date().timeIntervalSince(date) < 60 { return "방금 전" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("빈 상태") {
    HistoryView()
        .environment(\.termService, PreviewTermService())
        .preferredColorScheme(.dark)
}

#Preview("항목 있음") {
    HistoryView()
        .environment(
            \.termService,
            PreviewTermService(histories: [
                SearchHistory(keyword: "harness engineering"),
                SearchHistory(keyword: "mutex"),
                SearchHistory(keyword: "semaphore"),
                SearchHistory(keyword: "daemon"),
                SearchHistory(keyword: "kernel"),
                SearchHistory(keyword: "fork")
            ])
        )
        .preferredColorScheme(.dark)
}
