import XCTest
@testable import DevEtym

@MainActor
final class ClaudeAPIServiceTests: XCTestCase {

    // MARK: - HTTP Stub

    private final class StubHTTPClient: HTTPClient {
        var responseFactory: (URLRequest) throws -> (Data, URLResponse) = { _ in
            throw ClaudeAPIError.invalidResponse
        }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try responseFactory(request)
        }
    }

    private func envelope(text: String) -> Data {
        let payload: [String: Any] = [
            "content": [
                ["type": "text", "text": text]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private func okResponse() -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func makeService(stub: StubHTTPClient, apiKey: String? = "test-key") -> ClaudeAPIService {
        ClaudeAPIService(httpClient: stub, apiKeyProvider: { apiKey })
    }

    // MARK: - 테스트

    func test_generate_validTerm_returnsTermEntry() async throws {
        let stub = StubHTTPClient()
        let json = """
        {"keyword":"mutex","aliases":["뮤텍스"],"category":"동시성","summary":"s","etymology":"e","namingReason":"n"}
        """
        stub.responseFactory = { _ in (self.envelope(text: json), self.okResponse()) }

        let service = makeService(stub: stub)
        let entry = try await service.generate(keyword: "mutex")
        XCTAssertEqual(entry.keyword, "mutex")
        XCTAssertEqual(entry.aliases, ["뮤텍스"])
        XCTAssertEqual(entry.category, "동시성")
    }

    func test_generate_notDevTerm_throwsNotDevTerm() async {
        let stub = StubHTTPClient()
        let json = #"{"error":"NOT_DEV_TERM","suggestion":null}"#
        stub.responseFactory = { _ in (self.envelope(text: json), self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "사과")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .notDevTerm)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_possibleTypo_throwsWithSuggestion() async {
        let stub = StubHTTPClient()
        let json = #"{"error":"POSSIBLE_TYPO","suggestion":"mutex"}"#
        stub.responseFactory = { _ in (self.envelope(text: json), self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutx")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .possibleTypo(suggestion: "mutex"))
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_timeout_throwsTimeout() async {
        let stub = StubHTTPClient()
        stub.responseFactory = { _ in throw URLError(.timedOut) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_invalidJSON_throwsInvalidResponse() async {
        let stub = StubHTTPClient()
        stub.responseFactory = { _ in (self.envelope(text: "not json at all"), self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_markdownWrappedJSON_parsesCorrectly() async throws {
        let stub = StubHTTPClient()
        let wrapped = """
        ```json
        {"keyword":"mutex","aliases":["뮤텍스"],"category":"동시성","summary":"s","etymology":"e","namingReason":"n"}
        ```
        """
        stub.responseFactory = { _ in (self.envelope(text: wrapped), self.okResponse()) }

        let entry = try await makeService(stub: stub).generate(keyword: "mutex")
        XCTAssertEqual(entry.keyword, "mutex")
    }

    func test_generate_missingAPIKey_throwsInvalidAPIKey() async {
        let stub = StubHTTPClient()
        let service = makeService(stub: stub, apiKey: "")

        do {
            _ = try await service.generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_nilAPIKey_throwsInvalidAPIKey() async {
        let stub = StubHTTPClient()
        let service = makeService(stub: stub, apiKey: nil)

        do {
            _ = try await service.generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - stripMarkdownFence 단위 테스트

    func test_stripMarkdownFence_plainJSON_unchanged() {
        let input = #"{"a":1}"#
        XCTAssertEqual(ClaudeAPIService.stripMarkdownFence(from: input), input)
    }

    func test_stripMarkdownFence_jsonLangTag_stripped() {
        let input = "```json\n{\"a\":1}\n```"
        XCTAssertEqual(ClaudeAPIService.stripMarkdownFence(from: input), #"{"a":1}"#)
    }

    func test_stripMarkdownFence_noLangTag_stripped() {
        let input = "```\n{\"a\":1}\n```"
        XCTAssertEqual(ClaudeAPIService.stripMarkdownFence(from: input), #"{"a":1}"#)
    }
}
