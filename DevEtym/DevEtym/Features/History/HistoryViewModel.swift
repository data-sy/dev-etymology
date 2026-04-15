import Foundation

/// 히스토리 탭 뷰 모델
/// - 변경 액션 직후 수동 재조회로 UI 동기화
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var entries: [SearchHistory] = []
    @Published var errorMessage: String?

    var termService: (any TermServiceProtocol)?

    /// 전체 목록 갱신
    func refresh() {
        entries = termService?.recentSearches(limit: 100) ?? []
    }

    /// 단일 항목 삭제 → 직후 재조회
    func delete(_ keyword: String) {
        guard let service = termService else { return }
        do {
            try service.deleteSearchHistory(keyword)
            refresh()
        } catch {
            errorMessage = "히스토리 삭제에 실패했습니다"
        }
    }

    /// 전체 삭제 → 직후 재조회
    func clearAll() {
        guard let service = termService else { return }
        do {
            try service.clearAllSearchHistory()
            refresh()
        } catch {
            errorMessage = "히스토리 삭제에 실패했습니다"
        }
    }
}
