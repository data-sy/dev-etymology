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

    /// tool_use 블록 하나만 담은 Claude messages API 응답 봉투
    private func toolUseEnvelope(name: String, input: [String: Any]) -> Data {
        let payload: [String: Any] = [
            "content": [
                [
                    "type": "tool_use",
                    "id": "toolu_test",
                    "name": name,
                    "input": input
                ]
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

    private func validTermInput() -> [String: Any] {
        [
            "keyword": "mutex",
            "aliases": ["뮤텍스"],
            "category": "동시성",
            "summary": "s",
            "etymology": "e",
            "namingReason": "n"
        ]
    }

    // MARK: - 응답 분기 (tool_use 기반)

    func test_generate_termEntryTool_returnsTermEntry() async throws {
        let stub = StubHTTPClient()
        let data = toolUseEnvelope(name: "return_term_entry", input: validTermInput())
        stub.responseFactory = { _ in (data, self.okResponse()) }

        let entry = try await makeService(stub: stub).generate(keyword: "mutex")
        XCTAssertEqual(entry.keyword, "mutex")
        XCTAssertEqual(entry.aliases, ["뮤텍스"])
        XCTAssertEqual(entry.category, "동시성")
    }

    func test_generate_notDevTermTool_throwsNotDevTerm() async {
        let stub = StubHTTPClient()
        let data = toolUseEnvelope(name: "return_not_dev_term", input: [:])
        stub.responseFactory = { _ in (data, self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "사과")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .notDevTerm)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_possibleTypoTool_throwsWithSuggestion() async {
        let stub = StubHTTPClient()
        let data = toolUseEnvelope(name: "return_possible_typo", input: ["suggestion": "mutex"])
        stub.responseFactory = { _ in (data, self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutx")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .possibleTypo(suggestion: "mutex"))
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_unknownToolName_throwsInvalidResponse() async {
        let stub = StubHTTPClient()
        let data = toolUseEnvelope(name: "return_something_else", input: [:])
        stub.responseFactory = { _ in (data, self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_noToolUseBlock_throwsInvalidResponse() async {
        let stub = StubHTTPClient()
        // content에 text만 있고 tool_use가 없는 비정상 응답 (tool_choice: any 하에서는 일어나지 않아야 함)
        let payload: [String: Any] = [
            "content": [
                ["type": "text", "text": "plain text, no tool call"]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        stub.responseFactory = { _ in (data, self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_generate_termEntryToolWithMissingFields_throwsInvalidResponse() async {
        let stub = StubHTTPClient()
        // API가 input_schema를 강제하지만, 방어적으로 필수 필드 누락 시 파싱 실패 확인
        let incomplete: [String: Any] = ["keyword": "mutex", "aliases": ["뮤텍스"]]
        let data = toolUseEnvelope(name: "return_term_entry", input: incomplete)
        stub.responseFactory = { _ in (data, self.okResponse()) }

        do {
            _ = try await makeService(stub: stub).generate(keyword: "mutex")
            XCTFail("에러가 throw되어야 함")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - 전송/네트워크 계층

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

    // MARK: - 요청 body 검증

    func test_generate_requestBody_includesThinkingConfig() async throws {
        let stub = StubHTTPClient()
        var capturedBody: [String: Any]?
        let data = toolUseEnvelope(name: "return_term_entry", input: validTermInput())
        stub.responseFactory = { request in
            if let body = request.httpBody {
                capturedBody = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            return (data, self.okResponse())
        }

        _ = try await makeService(stub: stub).generate(keyword: "mutex")

        let thinking = capturedBody?["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "enabled")
        XCTAssertEqual(thinking?["budget_tokens"] as? Int, 2000)
        XCTAssertGreaterThan(capturedBody?["max_tokens"] as? Int ?? 0, 2000)
    }

    func test_generate_requestBody_systemBlockHasCacheControl() async throws {
        let stub = StubHTTPClient()
        var capturedBody: [String: Any]?
        let data = toolUseEnvelope(name: "return_term_entry", input: validTermInput())
        stub.responseFactory = { request in
            if let body = request.httpBody {
                capturedBody = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            return (data, self.okResponse())
        }

        _ = try await makeService(stub: stub).generate(keyword: "mutex")

        // system은 프롬프트 캐싱을 위해 cache_control이 붙은 블록 배열이어야 함
        let systemBlocks = capturedBody?["system"] as? [[String: Any]]
        XCTAssertEqual(systemBlocks?.count, 1)
        let first = systemBlocks?.first
        XCTAssertEqual(first?["type"] as? String, "text")
        XCTAssertFalse((first?["text"] as? String ?? "").isEmpty)
        let cacheControl = first?["cache_control"] as? [String: Any]
        XCTAssertEqual(cacheControl?["type"] as? String, "ephemeral")
    }

    func test_generate_requestBody_includesToolsAndToolChoice() async throws {
        let stub = StubHTTPClient()
        var capturedBody: [String: Any]?
        let data = toolUseEnvelope(name: "return_term_entry", input: validTermInput())
        stub.responseFactory = { request in
            if let body = request.httpBody {
                capturedBody = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            return (data, self.okResponse())
        }

        _ = try await makeService(stub: stub).generate(keyword: "mutex")

        let tools = capturedBody?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 3)
        let toolNames = Set(tools?.compactMap { $0["name"] as? String } ?? [])
        XCTAssertEqual(toolNames, ["return_term_entry", "return_not_dev_term", "return_possible_typo"])

        let toolChoice = capturedBody?["tool_choice"] as? [String: Any]
        XCTAssertEqual(toolChoice?["type"] as? String, "any")
    }

    func test_generate_responseWithThinkingBlock_findsToolUse() async throws {
        let stub = StubHTTPClient()
        // 실제 extended thinking + tool_use 응답 형태: thinking 블록이 tool_use 앞에 옴
        let payload: [String: Any] = [
            "content": [
                ["type": "thinking", "thinking": "mutex는 상호 배제..."],
                [
                    "type": "tool_use",
                    "id": "toolu_test",
                    "name": "return_term_entry",
                    "input": validTermInput()
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        stub.responseFactory = { _ in (data, self.okResponse()) }

        let entry = try await makeService(stub: stub).generate(keyword: "mutex")
        XCTAssertEqual(entry.keyword, "mutex")
    }

    // MARK: - systemPrompt sanity check

    func test_systemPrompt_containsFewShotExamples() {
        let prompt = ClaudeAPIService.systemPrompt
        XCTAssertTrue(prompt.contains("mutex"), "mutex 예시가 프롬프트에 포함되어야 함")
        XCTAssertTrue(prompt.contains("jpa") || prompt.contains("JPA"), "JPA 예시가 프롬프트에 포함되어야 함")
        XCTAssertTrue(prompt.contains("daemon"), "daemon 예시가 프롬프트에 포함되어야 함")
    }
}
