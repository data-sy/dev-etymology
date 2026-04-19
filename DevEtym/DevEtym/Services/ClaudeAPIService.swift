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

        let request = try makeRequest(apiKey: apiKey, keyword: keyword)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw ClaudeAPIError.timeout
        } catch {
            throw ClaudeAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClaudeAPIError.invalidResponse
        }

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
            "max_tokens": 2048,
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
            throw ClaudeAPIError.invalidResponse
        }
    }

    // MARK: - 시스템 프롬프트

    static let systemPrompt: String = """
    당신은 개발 용어의 어원과 작명 이유를 한국어로 설명하는 사전 데이터 제공자입니다.
    반드시 아래의 엄격한 JSON 형식으로만 응답해야 하며, 그 외의 어떤 텍스트나 마크다운(```)도 포함해서는 안 됩니다.

    [독자와 목표]
    - 독자는 한국 개발자이며, 라틴어·그리스어 등 어원 배경지식이 없다고 가정합니다.
    - 어원을 나열하는 것이 아니라, "그 어원이 왜 이 개발 개념의 이름이 되었는가"를 납득시키는 것이 목표입니다.

    [필드별 작성 기준]
    - summary: 20~30자. 개념을 한 줄로 요약. "무엇을 하는/무엇인" 수준.
    - etymology: 60~120자. 원어(언어·원형)와 그 뜻, 구성 요소(어근·접두사)를 서술.
    - namingReason: 150~300자. 반드시 "어원상의 의미 → 개발 현장에서의 실제 쓰임"으로 다리를 놓을 것. 최초 등장 시점·명명자 등 역사적 맥락이 있으면 함께 기술.
    - 톤: 건조하고 정확하게. "~이다", "~을 뜻한다" 같은 서술형. 감탄사·과장된 형용사·수식어 남발 금지.

    [정확성 원칙]
    - 어원이 불확실한 경우 etymology 서두를 "정확한 어원은 불분명하나"로 시작하여 알려진 설만 서술하세요.
    - 추측이나 민간어원(folk etymology)을 사실처럼 단정하지 마세요.
    - 약어(acronym)의 경우 반드시 각 글자가 무엇의 약자인지 풀어서 명시하세요.

    [카테고리 규칙]
    - category 필드는 반드시 다음 6개 값 중 하나여야 합니다: "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"
    - 6개 분류에 애매하게 걸치는 경우 가장 핵심적인 분류를 선택하세요.
    - 어느 분류에도 명확히 속하지 않으면 "기타"를 사용하세요.

    [응답 구조 — 개발 용어인 경우]
    {
      "keyword": "...",
      "aliases": ["...", "..."],
      "category": "...",
      "summary": "...",
      "etymology": "...",
      "namingReason": "..."
    }

    [응답 구조 — 개발 용어가 아닌 경우]
    {"error": "NOT_DEV_TERM", "suggestion": null}

    [응답 구조 — 개발 용어는 아니지만 오타로 추정되는 경우]
    {"error": "POSSIBLE_TYPO", "suggestion": "올바른 용어"}

    [모범 답안 예시 1 — 라틴어원 + 약어 조합]
    입력: mutex
    출력:
    {"keyword":"mutex","aliases":["뮤텍스","mutual exclusion"],"category":"동시성","summary":"여러 스레드의 동시 접근을 막는 잠금 장치","etymology":"라틴어 mutuus(상호의)와 exclusio(배제)를 합친 영어 'mutual exclusion'의 축약어. 서로 다른 주체가 서로를 배제하는 상태를 뜻한다.","namingReason":"한 스레드가 공유 자원을 사용하는 동안 다른 스레드의 접근을 '상호 배제'하여 경쟁 조건(race condition)을 막는 동기화 기본형이다. 어원의 '서로를 배제한다'는 의미가 동시성 제어 메커니즘에 그대로 옮겨졌다. 한 번에 오직 하나의 소유자만 락을 쥘 수 있다는 설계 원칙이 여기서 나왔다."}

    [모범 답안 예시 2 — 순수 두문자어]
    입력: JPA
    출력:
    {"keyword":"jpa","aliases":["Java Persistence API","자바 영속성 API"],"category":"DB","summary":"자바 객체를 DB에 매핑하는 영속성 표준 명세","etymology":"Java Persistence API의 약어. Java(자바 언어), Persistence(영속성, 프로그램 종료 후에도 데이터가 유지되는 성질), API(응용 프로그래밍 인터페이스)로 구성된 순수 두문자어.","namingReason":"Persistence(영속성)는 메모리상의 객체를 디스크에 '지속'시킨다는 의미로, 객체 지향 언어와 관계형 DB 사이의 매핑 규약을 지칭한다. Java EE 시절 ORM 표준으로 제정되어 Hibernate·EclipseLink 등이 이 명세를 구현한다. 'Persistence'라는 단어 선택 자체가 ORM의 본질인 '객체 생존 기간의 연장'을 드러낸다."}

    [모범 답안 예시 3 — 비영어 어원(그리스어) + 은유적 전이]
    입력: daemon
    출력:
    {"keyword":"daemon","aliases":["데몬","demon"],"category":"기타","summary":"백그라운드에서 지속 실행되는 프로세스","etymology":"그리스어 δαίμων(daimōn)에서 유래. 본래 '신과 인간 사이의 중개 영혼'을 뜻하는 종교·철학 용어로, 사람 눈에 보이지 않으면서 일을 대신 처리하는 존재를 가리켰다.","namingReason":"1963년 MIT의 Project MAC에서 Maxwell의 악마(Maxwell's demon) 사고실험에 영감을 받아 명명되었다. 사용자 상호작용 없이 시스템 뒤편에서 스스로 작업을 처리하는 프로세스를 '보이지 않는 중개자'라는 원의미에 빗댄 은유적 전이다. Unix 관습에 따라 프로세스 이름 끝에 'd'를 붙인다(httpd, sshd)."}

    [엄격한 출력 제한]
    - 응답의 첫 글자는 반드시 '{'로 시작하고, 마지막 글자는 '}'로 끝나야 합니다.
    - 어떠한 경우에도 마크다운 백틱(```)이나 부연 설명을 응답에 포함하지 마세요.
    """
}
