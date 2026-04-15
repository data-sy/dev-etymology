import Combine
import Foundation

/// 북마크 탭 뷰 모델
/// - @Query를 사용하지 않으므로 변경 액션 직후 수동으로 목록 재조회
@MainActor
final class BookmarkViewModel: ObservableObject {
    @Published var terms: [Term] = []
    @Published var errorMessage: String?

    var termService: (any TermServiceProtocol)?

    /// 목록 갱신 — .onAppear, 토글/삭제 직후 호출
    func refresh() {
        terms = termService?.bookmarkedTerms() ?? []
    }

    /// 북마크 해제 → 목록 즉시 재조회
    func removeBookmark(_ term: Term) {
        guard let service = termService else { return }
        do {
            _ = try service.toggleBookmark(for: term.toEntry())
            refresh()
        } catch {
            errorMessage = "북마크 변경에 실패했습니다"
        }
    }
}
