import SwiftUI

/// 상세 화면
/// - keyword를 받아 TermResult에 따라 분기 표시
/// - possibleTypo 시 추천 용어는 부모 NavigationStack의 path를 replace
struct DetailView: View {
    let keyword: String
    /// possibleTypo 추천 용어 탭 시 호출 (부모가 path.removeLast 후 append)
    var onSelectSuggestion: ((String) -> Void)?

    @Environment(\.termService) private var termService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DetailViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingView
            case .loaded(let result):
                loadedView(result)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 12) {
            ProgressView()
            Text("어원을 분석하는 중...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.keyword)
                            .font(.largeTitle.bold())
                        Text(entry.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    etymologyBlock(entry.etymology)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("작명 이유")
                            .font(.headline)
                        Text(entry.namingReason)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            reportButton(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleBookmark()
                } label: {
                    Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(viewModel.isBookmarked ? "북마크 해제" : "북마크 추가")
            }
        }
    }

    private func etymologyBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("어원")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var notDevTermView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("개발 용어를 검색해주세요")
                .font(.headline)
            Button("검색으로 돌아가기") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func possibleTypoView(suggestion: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("\(suggestion)을(를) 찾으셨나요?")
                .font(.headline)
            Button {
                onSelectSuggestion?(suggestion)
            } label: {
                Text(suggestion)
                    .font(.body.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            Button("아니요, 돌아가기") { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 오류 제보

    @ViewBuilder
    private func reportButton(entry: TermEntry) -> some View {
        VStack {
            Divider()
            if let url = reportMailtoURL(entry: entry) {
                Link(destination: url) {
                    Label("이 설명이 잘못됐나요? 오류 제보하기", systemImage: "envelope")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
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
        components.path = Constants.reportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

#Preview("found") {
    NavigationStack {
        DetailView(keyword: "mutex")
            .environment(\.termService, MockTermService())
    }
}

#Preview("notDevTerm") {
    NavigationStack {
        DetailView(keyword: "hello")
            .environment(\.termService, MockTermService(fetchResult: .notDevTerm))
    }
}

#Preview("possibleTypo") {
    NavigationStack {
        DetailView(keyword: "mutx")
            .environment(
                \.termService,
                MockTermService(fetchResult: .possibleTypo("mutex"))
            )
    }
}
