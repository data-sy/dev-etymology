import SwiftUI

/// 검색 탭 루트 View
/// - NavigationPath를 직접 소유하여 DetailView push/replace 제어
/// - possibleTypo 재검색은 path.removeLast() 후 새 keyword append
struct SearchView: View {
    @Environment(\.termService) private var termService
    @StateObject private var viewModel = SearchViewModel()
    @State private var path = NavigationPath()
    /// 검색필드 포커스 — 입력 중 안내 문구를 숨겨 하단 크롬 압박 완화(ⓒ).
    /// 입력 시작 시 키보드가 탭바를 자연히 덮으므로 탭바 수동 숨김은 불필요.
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            // 하단 고정 검색필드 — safeAreaInset이 키보드 위로 자동 회피(ⓑ)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
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

    /// 상단 헤더 + 본문(최근검색/자동완성). 본문은 하단(검색필드 바로 위)에 정렬되어
    /// 칩이 엄지 존에 들어오고, 자동완성은 위로 펼쳐진다(ⓐ).
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 20)
            if !viewModel.suggestions.isEmpty {
                suggestionList
            } else {
                Spacer(minLength: 16)
                recentSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    /// 하단 고정 바 — 안내 문구(평상시) + 검색필드
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isSearchFocused && viewModel.suggestions.isEmpty {
                hintText
            }
            searchField
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Theme.Palette.bg)
    }

    /// 헤더 — hero 스케일(DM Serif 28)로 앱 정체성 강조
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevEtym")
                .typoTitleHero()
                .foregroundStyle(Theme.Palette.text)
            Text("// 개발 용어 어원 사전")
                .typoLabel()
                .tracking(0.6)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DevEtym 개발 용어 어원 사전")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textMuted)
                .accessibilityHidden(true)
            TextField("", text: $viewModel.query, prompt: Text("mutex, semaphore, daemon...").foregroundColor(Theme.Palette.textMuted))
                .typoCodeInput()
                .foregroundStyle(Theme.Palette.text)
                .focused($isSearchFocused)
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
        .padding(.vertical, 13)
        .background(Theme.Palette.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.border, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var hintText: some View {
        Text("영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)")
            .typoLabel()
            .foregroundStyle(Theme.Palette.textMuted)
    }

    /// 자동완성 — 검색필드 바로 위에서 위로 펼침(ⓐ).
    /// ScrollView가 공간을 채우되 content를 하단에 고정해, 항목이 적으면 필드 위에 붙고
    /// 많으면 위로 자라며 스크롤된다(메신저식). 섹션 라벨은 목록과 함께 묶어 하단 정렬.
    private var suggestionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                sectionLabel("자동완성")
                ForEach(viewModel.suggestions, id: \.keyword) { entry in
                    Button {
                        path.append(entry.keyword)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.keyword)
                                .typoCodeBody()
                                .foregroundStyle(Theme.Palette.text)
                            Text(entry.summary)
                                .typoBodyPreview()
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .defaultScrollAnchor(.bottom)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("최근 검색")
            if viewModel.recent.isEmpty {
                Text("최근 검색한 용어가 없습니다")
                    .typoLabel()
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
            .typoCaption()
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
                            .typoCodeChip()
                            .foregroundStyle(Theme.Palette.textDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
