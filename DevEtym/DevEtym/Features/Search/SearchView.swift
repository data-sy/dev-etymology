import SwiftUI

/// 검색 탭 루트 View
/// - NavigationPath를 직접 소유하여 DetailView push/replace 제어
/// - possibleTypo 재검색은 path.removeLast() 후 새 keyword append
struct SearchView: View {
    @Environment(\.termService) private var termService
    @StateObject private var viewModel = SearchViewModel()
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
                DetailView(
                    keyword: keyword,
                    onSelectSuggestion: { suggestion in
                        if !path.isEmpty { path.removeLast() }
                        path.append(suggestion)
                    }
                )
            }
        }
        .onAppear {
            viewModel.termService = termService
            viewModel.refreshRecent()
        }
    }

    // MARK: - 컨텐츠

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            searchField
            hintText
            if !viewModel.suggestions.isEmpty {
                suggestionList
            } else {
                recentSection
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DevEtym")
                .font(Theme.Typography.titleTab)
                .foregroundStyle(Theme.Palette.text)
            Text("// 개발 용어 어원 사전")
                .font(Theme.Typography.label)
                .tracking(0.6)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DevEtym 개발 용어 어원 사전")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
            TextField("", text: $viewModel.query, prompt: Text("mutex, semaphore, daemon...").foregroundColor(Theme.Palette.textMuted))
                .font(Theme.Typography.codeInput)
                .foregroundStyle(Theme.Palette.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(submit)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.onQueryChanged(newValue)
                }
                .accessibilityLabel("용어 검색")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.Palette.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.border, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var hintText: some View {
        Text("영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)")
            .font(Theme.Typography.label)
            .foregroundStyle(Theme.Palette.textMuted)
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("자동완성")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.suggestions, id: \.keyword) { entry in
                        Button {
                            path.append(entry.keyword)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.keyword)
                                    .font(Theme.Typography.codeBody)
                                    .foregroundStyle(Theme.Palette.text)
                                Text(entry.summary)
                                    .font(Theme.Typography.bodyPreview)
                                    .foregroundStyle(Theme.Palette.textDim)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.keyword) 검색")
                        Divider().background(Theme.Palette.border)
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("최근 검색")
            if viewModel.recent.isEmpty {
                Text("최근 검색한 용어가 없습니다")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Palette.textMuted)
            } else {
                FlowChips(
                    items: viewModel.recent.map(\.keyword),
                    onTap: { keyword in path.append(keyword) }
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Typography.caption)
            .tracking(1.5)
            .foregroundStyle(Theme.Palette.textMuted)
            .padding(.bottom, 8)
    }

    // MARK: - 액션

    private func submit() {
        guard let keyword = viewModel.commit() else { return }
        path.append(keyword)
    }
}

/// 가로 배치 칩 — 줄 넘김 자동 처리
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onTap(item)
                    } label: {
                        Text(item)
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Palette.textDim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Theme.Palette.surface2)
                            )
                            .overlay(
                                Capsule().stroke(Theme.Palette.border, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("\(item) 다시 검색")
                }
            }
        }
    }
}

#Preview("기본") {
    SearchView()
        .environment(\.termService, PreviewTermService())
        .preferredColorScheme(.dark)
}

#Preview("히스토리 있음") {
    SearchView()
        .environment(
            \.termService,
            PreviewTermService(histories: [
                SearchHistory(keyword: "mutex"),
                SearchHistory(keyword: "deadlock"),
                SearchHistory(keyword: "jpa"),
                SearchHistory(keyword: "kernel"),
                SearchHistory(keyword: "fork")
            ])
        )
        .preferredColorScheme(.dark)
}
