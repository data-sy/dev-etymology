import Foundation

/// 모든 ViewModel이 의존하는 단일 오케스트레이터 프로토콜
/// 구현체(TermService)는 Phase 2에서 추가된다
@MainActor
protocol TermServiceProtocol {
    // MARK: - 검색
    func fetch(keyword: String) async throws -> TermResult
    func autocomplete(prefix: String) -> [TermEntry]

    // MARK: - 북마크
    func toggleBookmark(for entry: TermEntry) throws -> Bool
    func bookmarkedTerms() -> [Term]

    // MARK: - 히스토리
    func recentSearches(limit: Int) -> [SearchHistory]
    func deleteSearchHistory(_ keyword: String) throws
    func clearAllSearchHistory() throws
}
