import Foundation
@testable import DevEtym

/// 단위 테스트 및 Preview용 TermServiceProtocol 목(Mock) 구현
/// - 저장소가 아니므로 상태 변경을 메모리에만 반영
/// - fetchResult, autocompleteResult 등을 주입하여 시나리오별 UI를 검증
@MainActor
final class MockTermService: TermServiceProtocol {
    // MARK: - 주입 가능한 결과값

    /// fetch(keyword:) 호출 시 반환할 결과. nil이면 기본 sample 반환
    var fetchResult: TermResult?
    /// fetch가 throw할 에러 (테스트용)
    var fetchError: Error?
    /// fetchResult가 nil일 때 .found에 함께 실어 보낼 source 문자열
    var defaultSource: String = "bundle"
    /// 자동완성 후보
    var autocompleteEntries: [TermEntry] = MockTermService.sampleEntries
    /// 북마크된 Term 목록
    private var bookmarks: [Term] = []
    /// 검색 히스토리
    private var histories: [SearchHistory] = []

    // MARK: - 초기화

    init(
        fetchResult: TermResult? = nil,
        fetchError: Error? = nil,
        defaultSource: String = "bundle",
        autocompleteEntries: [TermEntry]? = nil,
        bookmarks: [Term] = [],
        histories: [SearchHistory] = []
    ) {
        self.fetchResult = fetchResult
        self.fetchError = fetchError
        self.defaultSource = defaultSource
        if let autocompleteEntries {
            self.autocompleteEntries = autocompleteEntries
        }
        self.bookmarks = bookmarks
        self.histories = histories
    }

    // MARK: - TermServiceProtocol

    func fetch(keyword: String) async throws -> TermResult {
        if let fetchError { throw fetchError }
        if let fetchResult { return fetchResult }
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return .notDevTerm }
        if let hit = MockTermService.sampleEntries.first(where: { $0.keyword == normalized }) {
            upsertHistory(keyword: normalized)
            return .found(hit, source: defaultSource)
        }
        // 샘플 외에는 기본적으로 mutex 반환 (Preview 편의)
        upsertHistory(keyword: normalized)
        return .found(MockTermService.sampleEntries[0], source: defaultSource)
    }

    func autocomplete(prefix: String) -> [TermEntry] {
        let normalized = prefix.lowercased()
        guard !normalized.isEmpty else { return [] }
        return autocompleteEntries.filter { $0.keyword.lowercased().hasPrefix(normalized) }
    }

    func toggleBookmark(for entry: TermEntry) throws -> Bool {
        if let idx = bookmarks.firstIndex(where: { $0.keyword == entry.keyword.lowercased() }) {
            bookmarks.remove(at: idx)
            return false
        }
        bookmarks.append(Term(from: entry, source: "bundle", isBookmarked: true))
        return true
    }

    func bookmarkedTerms() -> [Term] {
        bookmarks.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func recentSearches(limit: Int) -> [SearchHistory] {
        Array(histories.sorted(by: { $0.searchedAt > $1.searchedAt }).prefix(limit))
    }

    func deleteSearchHistory(_ keyword: String) throws {
        histories.removeAll { $0.keyword == keyword }
    }

    func clearAllSearchHistory() throws {
        histories.removeAll()
    }

    // MARK: - 내부 헬퍼

    private func upsertHistory(keyword: String) {
        if let existing = histories.first(where: { $0.keyword == keyword }) {
            existing.searchedAt = .now
        } else {
            histories.append(SearchHistory(keyword: keyword))
        }
    }

    // MARK: - 샘플 데이터

    static let sampleEntries: [TermEntry] = [
        TermEntry(
            keyword: "mutex",
            aliases: ["뮤텍스", "mutual exclusion"],
            category: "동시성",
            summary: "동시 접근을 막는 잠금 장치",
            etymology: "라틴어 mutuus(상호의) + exclusio(배제) → Mutual Exclusion의 줄임말",
            namingReason: "두 스레드가 동시에 같은 자원에 접근하지 못하도록 서로(mutual) 차단(exclusion)하는 개념에서 유래"
        ),
        TermEntry(
            keyword: "deadlock",
            aliases: ["데드락", "교착 상태"],
            category: "동시성",
            summary: "서로가 서로의 자원을 기다려 아무도 진행하지 못하는 상태",
            etymology: "dead(죽은) + lock(잠금)",
            namingReason: "자원 획득 순서 순환으로 어느 쪽도 락을 놓지 못해 '죽은 잠금' 상태가 되는 현상"
        ),
        TermEntry(
            keyword: "jpa",
            aliases: ["제이피에이", "java persistence api"],
            category: "DB",
            summary: "자바 ORM 표준 명세",
            etymology: "Java Persistence API의 약자",
            namingReason: "자바 객체의 영속성(persistence)을 표준 API로 추상화한 데서 유래"
        )
    ]
}
