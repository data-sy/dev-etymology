import Foundation

@MainActor
protocol ClaudeAPIServiceProtocol {
    func generate(keyword: String) async throws -> TermEntry
}

/// URLSession 추상화 (테스트 주입용)
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

@MainActor
final class ClaudeAPIService: ClaudeAPIServiceProtocol {
    private let httpClient: HTTPClient
    private let apiKeyProvider: () -> String?
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    nonisolated init(
        httpClient: HTTPClient = URLSession.shared,
        apiKeyProvider: @escaping @Sendable () -> String? = {
            Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String
        }
    ) {
        self.httpClient = httpClient
        self.apiKeyProvider = apiKeyProvider
    }

    func generate(keyword: String) async throws -> TermEntry {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw ClaudeAPIError.invalidAPIKey
        }

        #if DEBUG
        print("🌐 [ClaudeAPI] 요청 시작: keyword='\(keyword)', model=\(Constants.claudeModel)")
        #endif

        let request = try makeRequest(apiKey: apiKey, keyword: keyword)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            #if DEBUG
            print("❌ [ClaudeAPI] 타임아웃")
            #endif
            throw ClaudeAPIError.timeout
        } catch {
            #if DEBUG
            print("❌ [ClaudeAPI] 네트워크 에러: \(error)")
            #endif
            throw ClaudeAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            #if DEBUG
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(디코딩 불가)"
            print("❌ [ClaudeAPI] HTTP \(statusCode) 에러 응답:\n\(body)")
            #endif
            throw ClaudeAPIError.invalidResponse
        }

        #if DEBUG
        print("✅ [ClaudeAPI] HTTP 200 수신, 본문 크기: \(data.count) bytes")
        #endif

        let text = try extractText(from: data)
        let cleaned = Self.stripMarkdownFence(from: text)
        return try parse(jsonText: cleaned)
    }

    // MARK: - 요청 생성

    private func makeRequest(apiKey: String, keyword: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.apiTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Constants.claudeModel,
            "max_tokens": 1024,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": keyword]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - 응답 파싱

    /// Claude messages API 응답 봉투에서 content[0].text 추출
    private func extractText(from data: Data) throws -> String {
        struct Envelope: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let content: [Content]
        }
        guard
            let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
            let text = envelope.content.first(where: { $0.type == "text" })?.text
        else {
            throw ClaudeAPIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// ```json ... ``` 또는 ``` ... ``` 마크다운 블록 감싸기를 제거
    /// 프롬프트로 금지했으나 방어적 전처리
    static func stripMarkdownFence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        var working = trimmed
        working.removeFirst(3) // 시작 fence
        // 첫 줄은 선택적 언어 태그("json" 등) — 줄바꿈까지 버린다
        if let newlineIndex = working.firstIndex(of: "\n") {
            working.removeSubrange(...newlineIndex)
        }
        if working.hasSuffix("```") {
            working.removeLast(3)
        }
        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parse(jsonText: String) throws -> TermEntry {
        guard let data = jsonText.data(using: .utf8) else {
            throw ClaudeAPIError.invalidResponse
        }

        #if DEBUG
        print("🤖 [ClaudeAPI] 원본 응답 텍스트:\n\(jsonText)")
        #endif

        if let errorResponse = try? JSONDecoder().decode(AIErrorResponse.self, from: data),
           !errorResponse.error.isEmpty {
            switch errorResponse.error {
            case "NOT_DEV_TERM":
                throw ClaudeAPIError.notDevTerm
            case "POSSIBLE_TYPO":
                throw ClaudeAPIError.possibleTypo(suggestion: errorResponse.suggestion ?? "")
            default:
                throw ClaudeAPIError.invalidResponse
            }
        }

        do {
            return try JSONDecoder().decode(TermEntry.self, from: data)
        } catch {
            #if DEBUG
            print("❌ [ClaudeAPI] TermEntry 디코딩 실패: \(error)")
            print("   JSON 원본: \(jsonText)")
            #endif
            throw ClaudeAPIError.invalidResponse
        }
    }

    // MARK: - 시스템 프롬프트

    static let systemPrompt: String = """
    당신은 개발 용어의 어원을 설명하는 사전 데이터 제공자입니다.
    반드시 아래의 엄격한 JSON 형식으로만 응답해야 하며, 그 외의 어떤 텍스트나 마크다운(```)도 포함해서는 안 됩니다.

    [개발 용어인 경우의 응답 구조]
    {
      "keyword": "mutex",
      "aliases": ["뮤텍스", "mutual exclusion"],
      "category": "동시성",
      "summary": "동시 접근을 막는 잠금 장치",
      "etymology": "라틴어 mutuus(상호의) + exclusio(배제)",
      "namingReason": "두 스레드가 동시에 접근하지 못하도록..."
    }

    [개발 용어가 아닌 경우의 응답 구조]
    {"error": "NOT_DEV_TERM", "suggestion": null}

    [개발 용어는 아니지만 오타로 추정되는 경우의 응답 구조]
    {"error": "POSSIBLE_TYPO", "suggestion": "올바른 용어"}

    [엄격한 출력 제한]
    응답의 첫 글자는 반드시 '{'로 시작하고, 마지막 글자는 '}'로 끝나야 합니다.
    어떠한 경우에도 마크다운 백틱(```)이나 부연 설명을 텍스트에 포함하지 마세요.

    [카테고리 규칙]
    - category 필드는 반드시 다음 6개 값 중 하나여야 합니다: "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"
    - 6개 분류에 애매하게 걸치는 경우 가장 핵심적인 분류를 선택하세요.
    - 어느 분류에도 명확히 속하지 않으면 "기타"를 사용하세요.

    [주의사항]
    - 어원이 불확실한 경우 "정확한 어원은 불분명하나"로 시작하여 알려진 설만 서술하세요.
    - 추측이나 민간어원(folk etymology)을 사실처럼 서술하지 마세요.
    - 약어의 경우 반드시 각 글자가 무엇의 약자인지 명시하세요.
    """
}
