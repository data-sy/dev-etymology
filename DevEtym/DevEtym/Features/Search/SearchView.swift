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
            content
                .navigationTitle("개발 어원 사전")
                .navigationDestination(for: String.self) { keyword in
                    DetailView(
                        keyword: keyword,
                        onSelectSuggestion: { suggestion in
                            // possibleTypo → replace (push 아닌 교체)
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

    // MARK: - 하위 구성

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchField
            hintText
            if !viewModel.suggestions.isEmpty {
                suggestionList
            } else {
                recentSection
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("용어를 입력하세요", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(submit)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.onQueryChanged(newValue)
                }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var hintText: some View {
        Text("영문 개발 용어를 입력해주세요 (예: mutex, JPA, deadlock)")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var suggestionList: some View {
        List(viewModel.suggestions, id: \.keyword) { entry in
            Button {
                path.append(entry.keyword)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.keyword).font(.body)
                    Text(entry.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .listStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 검색")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            if viewModel.recent.isEmpty {
                Text("최근 검색한 용어가 없습니다")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.recent, id: \.keyword) { history in
                            Button {
                                path.append(history.keyword)
                            } label: {
                                Text(history.keyword)
                                    .font(.footnote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color(.secondarySystemBackground))
                                    )
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 액션

    private func submit() {
        guard let keyword = viewModel.commit() else { return }
        path.append(keyword)
    }
}

#Preview("기본") {
    SearchView()
        .environment(\.termService, MockTermService())
}

#Preview("히스토리 있음") {
    SearchView()
        .environment(
            \.termService,
            MockTermService(histories: [
                SearchHistory(keyword: "mutex"),
                SearchHistory(keyword: "deadlock"),
                SearchHistory(keyword: "jpa")
            ])
        )
}
