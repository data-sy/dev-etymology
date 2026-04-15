import XCTest
@testable import DevEtym

@MainActor
final class BundleDBServiceTests: XCTestCase {
    private var service: BundleDBService!

    override func setUp() {
        super.setUp()
        service = BundleDBService(terms: [
            TermEntry(
                keyword: "mutex",
                aliases: ["뮤텍스", "mutual exclusion"],
                category: "동시성",
                summary: "요약",
                etymology: "어원",
                namingReason: "작명"
            ),
            TermEntry(
                keyword: "mutation",
                aliases: ["뮤테이션"],
                category: "기타",
                summary: "요약",
                etymology: "어원",
                namingReason: "작명"
            ),
            TermEntry(
                keyword: "stack",
                aliases: ["스택"],
                category: "자료구조",
                summary: "요약",
                etymology: "어원",
                namingReason: "작명"
            )
        ])
    }

    func test_search_exactKeyword_returnsEntry() {
        XCTAssertEqual(service.search(keyword: "mutex")?.keyword, "mutex")
    }

    func test_search_alias_returnsEntry() {
        XCTAssertEqual(service.search(keyword: "뮤텍스")?.keyword, "mutex")
        XCTAssertEqual(service.search(keyword: "mutual exclusion")?.keyword, "mutex")
    }

    func test_search_caseInsensitive_returnsEntry() {
        XCTAssertEqual(service.search(keyword: "MUTEX")?.keyword, "mutex")
        XCTAssertEqual(service.search(keyword: "  Mutex  ")?.keyword, "mutex")
    }

    func test_search_notFound_returnsNil() {
        XCTAssertNil(service.search(keyword: "nonexistent"))
        XCTAssertNil(service.search(keyword: ""))
    }

    func test_autocomplete_prefix_returnsMatches() {
        let results = service.autocomplete(prefix: "mu")
        let keywords = results.map(\.keyword)
        XCTAssertTrue(keywords.contains("mutex"))
        XCTAssertTrue(keywords.contains("mutation"))
        XCTAssertFalse(keywords.contains("stack"))
    }

    func test_autocomplete_empty_returnsEmpty() {
        XCTAssertTrue(service.autocomplete(prefix: "").isEmpty)
        XCTAssertTrue(service.autocomplete(prefix: "   ").isEmpty)
    }
}
