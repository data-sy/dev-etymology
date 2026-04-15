#if DEBUG
import Foundation

/// SwiftUI #Preview 캔버스 전용 TermServiceProtocol 구현
///
/// 단위 테스트는 DevEtymTests 타겟의 MockTermService를 사용한다.
/// 본 파일은 메인 앱 타겟에서 Preview 컴파일 시에만 포함된다 (#if DEBUG).
/// Preview용 샘플 데이터 팩토리도 함께 제공한다.
@MainActor
final class PreviewTermService: TermServiceProtocol {
    var fetchResult: TermResult?
    var fetchError: Error?
    var defaultSource: String = "bundle"
    var autocompleteEntries: [TermEntry] = PreviewSamples.entries
    private var bookmarks: [Term] = []
    private var histories: [SearchHistory] = []

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

    func fetch(keyword: String) async throws -> TermResult {
        if let fetchError { throw fetchError }
        if let fetchResult { return fetchResult }
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return .notDevTerm }
        if let hit = PreviewSamples.entries.first(where: { $0.keyword == normalized }) {
            upsertHistory(keyword: normalized)
            return .found(hit, source: defaultSource)
        }
        upsertHistory(keyword: normalized)
        return .found(PreviewSamples.entries[0], source: defaultSource)
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

    private func upsertHistory(keyword: String) {
        if let existing = histories.first(where: { $0.keyword == keyword }) {
            existing.searchedAt = .now
        } else {
            histories.append(SearchHistory(keyword: keyword))
        }
    }
}

/// Preview에서 사용하는 샘플 TermEntry 팩토리
enum PreviewSamples {
    static let entries: [TermEntry] = [
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
            keyword: "harness",
            aliases: ["하네스"],
            category: "기타",
            summary: "테스트 대상 코드를 외부에서 통제하고 실행하기 위한 프레임워크",
            etymology: "고대 프랑스어 harneis(말 장구, 마구) — 제어를 위해 묶고 연결하는 도구",
            namingReason: "말에 마구를 채워 제어하듯, test harness는 테스트 대상 코드를 외부에서 통제하고 실행하기 위한 구조를 의미한다"
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
#endif
