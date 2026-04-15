import XCTest
import SwiftData
@testable import DevEtym

@MainActor
final class TermServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var bundleMock: MockBundleDBService!
    private var apiMock: MockClaudeAPIService!
    private var service: TermService!

    override func setUp() async throws {
        let schema = Schema([Term.self, SearchHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        bundleMock = MockBundleDBService(terms: [
            TermEntry(
                keyword: "mutex",
                aliases: ["뮤텍스", "mutual exclusion"],
                summary: "요약",
                etymology: "어원",
                namingReason: "작명"
            )
        ])
        apiMock = MockClaudeAPIService()
        service = TermService(
            modelContext: context,
            bundleDBService: bundleMock,
            claudeAPIService: apiMock
        )
    }

    // MARK: - 헬퍼

    private func aiEntry(keyword: String = "goroutine") -> TermEntry {
        TermEntry(
            keyword: keyword,
            aliases: ["고루틴"],
            summary: "s",
            etymology: "e",
            namingReason: "n"
        )
    }

    private func fetchAllTerms() -> [Term] {
        (try? context.fetch(FetchDescriptor<Term>())) ?? []
    }

    private func fetchAllHistory() -> [SearchHistory] {
        (try? context.fetch(FetchDescriptor<SearchHistory>())) ?? []
    }

    // MARK: - fetch

    func test_fetch_emptyInput_returnsNotDevTerm() async throws {
        let result = try await service.fetch(keyword: "   ")
        guard case .notDevTerm = result else {
            XCTFail("빈 입력은 .notDevTerm이어야 함")
            return
        }
        XCTAssertTrue(apiMock.generateCalls.isEmpty)
    }

    func test_fetch_bundleHit_returnsImmediately() async throws {
        let result = try await service.fetch(keyword: "MUTEX")
        guard case .found(let entry) = result else {
            XCTFail(".found 예상")
            return
        }
        XCTAssertEqual(entry.keyword, "mutex")
        XCTAssertTrue(apiMock.generateCalls.isEmpty)
    }

    func test_fetch_bundleAlias_returnsCorrectTerm() async throws {
        let result = try await service.fetch(keyword: "뮤텍스")
        guard case .found(let entry) = result else {
            XCTFail(".found 예상")
            return
        }
        XCTAssertEqual(entry.keyword, "mutex")
    }

    func test_fetch_bundleMiss_callsClaudeAPI() async throws {
        apiMock.result = .success(aiEntry())

        _ = try await service.fetch(keyword: "goroutine")
        XCTAssertEqual(apiMock.generateCalls, ["goroutine"])
    }

    func test_fetch_cachedResult_skipsAPI() async throws {
        apiMock.result = .success(aiEntry())
        _ = try await service.fetch(keyword: "goroutine")
        apiMock.generateCalls.removeAll()

        // 2회차: 캐시된 Term이 있으므로 API를 호출하지 않아야 함
        let result = try await service.fetch(keyword: "goroutine")
        guard case .found = result else {
            XCTFail(".found 예상")
            return
        }
        XCTAssertTrue(apiMock.generateCalls.isEmpty)
    }

    func test_fetch_apiError_throwsError() async {
        apiMock.result = .failure(ClaudeAPIError.invalidAPIKey)

        do {
            _ = try await service.fetch(keyword: "goroutine")
            XCTFail("에러 throw 기대")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_fetch_notDevTerm_returnsNotDevTerm() async throws {
        apiMock.result = .failure(ClaudeAPIError.notDevTerm)

        let result = try await service.fetch(keyword: "사과")
        guard case .notDevTerm = result else {
            XCTFail(".notDevTerm 예상")
            return
        }
    }

    func test_fetch_possibleTypo_returnsSuggestion() async throws {
        apiMock.result = .failure(ClaudeAPIError.possibleTypo(suggestion: "mutex"))

        let result = try await service.fetch(keyword: "mutx")
        guard case .possibleTypo(let suggestion) = result else {
            XCTFail(".possibleTypo 예상")
            return
        }
        XCTAssertEqual(suggestion, "mutex")
    }

    func test_fetch_success_savesHistory() async throws {
        _ = try await service.fetch(keyword: "mutex")
        let history = fetchAllHistory()
        XCTAssertEqual(history.map(\.keyword), ["mutex"])
    }

    func test_fetch_failure_doesNotSaveHistory() async {
        apiMock.result = .failure(ClaudeAPIError.notDevTerm)
        _ = try? await service.fetch(keyword: "사과")
        XCTAssertTrue(fetchAllHistory().isEmpty)

        apiMock.result = .failure(ClaudeAPIError.possibleTypo(suggestion: "mutex"))
        _ = try? await service.fetch(keyword: "mutx")
        XCTAssertTrue(fetchAllHistory().isEmpty)

        apiMock.result = .failure(ClaudeAPIError.invalidAPIKey)
        _ = try? await service.fetch(keyword: "whatever")
        XCTAssertTrue(fetchAllHistory().isEmpty)
    }

    func test_fetch_existingTerm_updatesFieldsPreservesBookmark() async throws {
        // 기존 Term: 북마크됨, source=bundle
        let existing = Term(
            keyword: "goroutine",
            aliases: ["예전"],
            summary: "예전 요약",
            etymology: "예전 어원",
            namingReason: "예전 작명",
            source: "bundle",
            isBookmarked: true
        )
        context.insert(existing)
        try context.save()

        apiMock.result = .success(aiEntry())
        _ = try await service.fetch(keyword: "goroutine")

        let terms = fetchAllTerms()
        XCTAssertEqual(terms.count, 1)
        let updated = terms[0]
        XCTAssertEqual(updated.summary, "s")
        XCTAssertEqual(updated.aliases, ["고루틴"])
        XCTAssertTrue(updated.isBookmarked)      // 보존
        XCTAssertEqual(updated.source, "bundle") // 보존
    }

    // MARK: - autocomplete

    func test_autocomplete_delegatesToBundleDB() {
        _ = service.autocomplete(prefix: "mu")
        XCTAssertEqual(bundleMock.autocompleteCalls, ["mu"])
    }

    // MARK: - 북마크

    func test_toggleBookmark_existingTerm_togglesValue() throws {
        let existing = Term(
            keyword: "goroutine",
            aliases: [],
            summary: "s",
            etymology: "e",
            namingReason: "n",
            source: "ai",
            isBookmarked: false
        )
        context.insert(existing)
        try context.save()

        let entry = TermEntry(
            keyword: "goroutine",
            aliases: [],
            summary: "s",
            etymology: "e",
            namingReason: "n"
        )

        XCTAssertTrue(try service.toggleBookmark(for: entry))
        XCTAssertFalse(try service.toggleBookmark(for: entry))
    }

    func test_toggleBookmark_bundleTerm_createsTerm() throws {
        let entry = TermEntry(
            keyword: "mutex",
            aliases: ["뮤텍스"],
            summary: "s",
            etymology: "e",
            namingReason: "n"
        )
        XCTAssertTrue(fetchAllTerms().isEmpty)

        let result = try service.toggleBookmark(for: entry)
        XCTAssertTrue(result)

        let terms = fetchAllTerms()
        XCTAssertEqual(terms.count, 1)
        XCTAssertEqual(terms[0].keyword, "mutex")
        XCTAssertTrue(terms[0].isBookmarked)
        XCTAssertEqual(terms[0].source, "bundle")
        XCTAssertEqual(terms[0].aliases, ["뮤텍스"])
    }

    func test_bookmarkedTerms_returnsOnlyBookmarked() throws {
        context.insert(Term(keyword: "a", summary: "", etymology: "", namingReason: "", isBookmarked: true))
        context.insert(Term(keyword: "b", summary: "", etymology: "", namingReason: "", isBookmarked: false))
        context.insert(Term(keyword: "c", summary: "", etymology: "", namingReason: "", isBookmarked: true))
        try context.save()

        let bookmarked = service.bookmarkedTerms()
        XCTAssertEqual(Set(bookmarked.map(\.keyword)), ["a", "c"])
    }

    // MARK: - 히스토리

    func test_recentSearches_returnsInOrder() async throws {
        _ = try await service.fetch(keyword: "mutex")
        try await Task.sleep(nanoseconds: 10_000_000)

        // 새 번들 항목 추가 후 다시 검색
        bundleMock.terms.append(TermEntry(
            keyword: "thread",
            aliases: ["스레드"],
            summary: "s", etymology: "e", namingReason: "n"
        ))
        _ = try await service.fetch(keyword: "thread")

        let recent = service.recentSearches(limit: 5)
        XCTAssertEqual(recent.map(\.keyword), ["thread", "mutex"])
    }

    func test_recentSearches_respectsLimit() async throws {
        bundleMock.terms = ["a", "b", "c"].map {
            TermEntry(keyword: $0, aliases: ["ko"], summary: "", etymology: "", namingReason: "")
        }
        for kw in ["a", "b", "c"] {
            _ = try await service.fetch(keyword: kw)
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertEqual(service.recentSearches(limit: 2).count, 2)
    }

    func test_deleteSearchHistory_removesEntry() async throws {
        _ = try await service.fetch(keyword: "mutex")
        XCTAssertFalse(fetchAllHistory().isEmpty)

        try service.deleteSearchHistory("mutex")
        XCTAssertTrue(fetchAllHistory().isEmpty)
    }

    func test_clearAllSearchHistory_removesAll() async throws {
        bundleMock.terms.append(TermEntry(
            keyword: "thread", aliases: ["스레드"],
            summary: "", etymology: "", namingReason: ""
        ))
        _ = try await service.fetch(keyword: "mutex")
        _ = try await service.fetch(keyword: "thread")
        XCTAssertEqual(fetchAllHistory().count, 2)

        try service.clearAllSearchHistory()
        XCTAssertTrue(fetchAllHistory().isEmpty)
    }

    func test_fetch_sameKeyword_updatesHistorySearchedAt() async throws {
        _ = try await service.fetch(keyword: "mutex")
        let firstDate = fetchAllHistory().first?.searchedAt

        try await Task.sleep(nanoseconds: 20_000_000)
        _ = try await service.fetch(keyword: "mutex")
        let history = fetchAllHistory()

        XCTAssertEqual(history.count, 1) // 중복 생성 아닌 갱신
        if let first = firstDate, let updated = history.first?.searchedAt {
            XCTAssertGreaterThan(updated, first)
        }
    }
}
