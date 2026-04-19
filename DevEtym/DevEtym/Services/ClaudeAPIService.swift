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

        return try Self.extractTermEntry(from: data)
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
            "max_tokens": 4096,
            "thinking": [
                "type": "enabled",
                "budget_tokens": 2000
            ],
            "system": [
                [
                    "type": "text",
                    "text": Self.systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "tools": Self.tools,
            "tool_choice": ["type": "any"],
            "messages": [
                ["role": "user", "content": keyword]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - 응답 파싱

    /// Claude messages API 응답에서 tool_use 블록을 찾아 TermEntry 또는 오류로 변환.
    /// tool_choice: any 설정으로 모델은 반드시 셋 중 하나의 도구를 호출한다.
    static func extractTermEntry(from data: Data) throws -> TermEntry {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]] else {
            throw ClaudeAPIError.invalidResponse
        }

        guard let toolUse = content.first(where: { ($0["type"] as? String) == "tool_use" }),
              let name = toolUse["name"] as? String,
              let input = toolUse["input"] as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }

        switch name {
        case Tool.termEntry:
            guard let inputData = try? JSONSerialization.data(withJSONObject: input),
                  let entry = try? JSONDecoder().decode(TermEntry.self, from: inputData) else {
                throw ClaudeAPIError.invalidResponse
            }
            return entry
        case Tool.notDevTerm:
            throw ClaudeAPIError.notDevTerm
        case Tool.possibleTypo:
            let suggestion = (input["suggestion"] as? String) ?? ""
            throw ClaudeAPIError.possibleTypo(suggestion: suggestion)
        default:
            throw ClaudeAPIError.invalidResponse
        }
    }

    // MARK: - 도구 정의

    enum Tool {
        static let termEntry = "return_term_entry"
        static let notDevTerm = "return_not_dev_term"
        static let possibleTypo = "return_possible_typo"
    }

    static let tools: [[String: Any]] = [
        [
            "name": Tool.termEntry,
            "description": "입력이 개발 용어로 판단될 때 호출합니다. 어원과 작명 이유를 각 필드에 채워 반환합니다.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "keyword": [
                        "type": "string",
                        "description": "영문 소문자 표기. 입력이 한글이거나 대문자여도 정규화하여 넣습니다."
                    ],
                    "aliases": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "한글 표기나 풀네임 등 대체 이름의 배열"
                    ],
                    "category": [
                        "type": "string",
                        "enum": TermEntry.allowedCategories
                    ],
                    "summary": [
                        "type": "string",
                        "description": "20~30자 분량의 한 줄 요약"
                    ],
                    "etymology": [
                        "type": "string",
                        "description": "60~120자 분량. 원어(언어·원형)와 뜻, 구성 요소(어근·접두사)를 서술."
                    ],
                    "namingReason": [
                        "type": "string",
                        "description": "150~300자 분량. 어원상 의미와 개발 현장에서의 실제 쓰임 사이에 다리를 놓는 설명."
                    ]
                ],
                "required": ["keyword", "aliases", "category", "summary", "etymology", "namingReason"]
            ]
        ],
        [
            "name": Tool.notDevTerm,
            "description": "입력이 개발 용어가 아닐 때 호출합니다. 입력값은 없습니다.",
            "input_schema": [
                "type": "object",
                "properties": [String: Any]()
            ]
        ],
        [
            "name": Tool.possibleTypo,
            "description": "입력이 개발 용어가 아니지만 개발 용어의 오타로 추정될 때 호출합니다.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "suggestion": [
                        "type": "string",
                        "description": "오타를 교정한 올바른 개발 용어"
                    ]
                ],
                "required": ["suggestion"]
            ]
        ]
    ]

    // MARK: - 시스템 프롬프트

    static let systemPrompt: String = """
    당신은 개발 용어의 어원과 작명 이유를 한국어로 설명하는 사전 데이터 제공자입니다.

    [독자와 목표]
    - 독자는 한국 개발자이며, 라틴어·그리스어 등 어원 배경지식이 없다고 가정합니다.
    - 어원을 나열하는 것이 아니라, "그 어원이 왜 이 개발 개념의 이름이 되었는가"를 납득시키는 것이 목표입니다.

    [도구 선택]
    - 입력이 개발 용어로 판단되면 return_term_entry 도구를 호출하여 각 필드를 채우세요.
    - 입력이 개발 용어가 아니면 return_not_dev_term 도구를 호출하세요.
    - 입력이 개발 용어의 오타로 추정되면 return_possible_typo 도구를 호출하고 suggestion에 올바른 용어를 넣으세요.

    [필드별 작성 기준 — return_term_entry]
    - summary: 20~30자. 개념을 한 줄로 요약. "무엇을 하는/무엇인" 수준.
    - etymology: 60~120자. 원어(언어·원형)와 그 뜻, 구성 요소(어근·접두사)를 서술.
    - namingReason: 150~300자. 반드시 "어원상의 의미 → 개발 현장에서의 실제 쓰임"으로 다리를 놓을 것. 최초 등장 시점·명명자 등 역사적 맥락이 있으면 함께 기술.
    - 톤: 건조하고 정확하게. "~이다", "~을 뜻한다" 같은 서술형. 감탄사·과장된 형용사·수식어 남발 금지.

    [정확성 원칙]
    - 어원이 불확실한 경우 etymology 서두를 "정확한 어원은 불분명하나"로 시작하여 알려진 설만 서술하세요.
    - 추측이나 민간어원(folk etymology)을 사실처럼 단정하지 마세요.
    - 약어(acronym)의 경우 반드시 각 글자가 무엇의 약자인지 풀어서 명시하세요.

    [카테고리 규칙]
    - category 값은 스키마의 enum에 명시된 6개 중 하나여야 합니다.
    - 6개 분류에 애매하게 걸치는 경우 가장 핵심적인 분류를 선택하세요.
    - 어느 분류에도 명확히 속하지 않으면 "기타"를 사용하세요.

    [모범 답안 예시 1 — 라틴어원 + 약어 조합]
    입력: mutex
    return_term_entry input:
    {"keyword":"mutex","aliases":["뮤텍스","mutual exclusion"],"category":"동시성","summary":"여러 스레드의 동시 접근을 막는 잠금 장치","etymology":"라틴어 mutuus(상호의)와 exclusio(배제)를 합친 영어 'mutual exclusion'의 축약어. 서로 다른 주체가 서로를 배제하는 상태를 뜻한다.","namingReason":"한 스레드가 공유 자원을 사용하는 동안 다른 스레드의 접근을 '상호 배제'하여 경쟁 조건(race condition)을 막는 동기화 기본형이다. 어원의 '서로를 배제한다'는 의미가 동시성 제어 메커니즘에 그대로 옮겨졌다. 한 번에 오직 하나의 소유자만 락을 쥘 수 있다는 설계 원칙이 여기서 나왔다."}

    [모범 답안 예시 2 — 순수 두문자어]
    입력: JPA
    return_term_entry input:
    {"keyword":"jpa","aliases":["Java Persistence API","자바 영속성 API"],"category":"DB","summary":"자바 객체를 DB에 매핑하는 영속성 표준 명세","etymology":"Java Persistence API의 약어. Java(자바 언어), Persistence(영속성, 프로그램 종료 후에도 데이터가 유지되는 성질), API(응용 프로그래밍 인터페이스)로 구성된 순수 두문자어.","namingReason":"Persistence(영속성)는 메모리상의 객체를 디스크에 '지속'시킨다는 의미로, 객체 지향 언어와 관계형 DB 사이의 매핑 규약을 지칭한다. Java EE 시절 ORM 표준으로 제정되어 Hibernate·EclipseLink 등이 이 명세를 구현한다. 'Persistence'라는 단어 선택 자체가 ORM의 본질인 '객체 생존 기간의 연장'을 드러낸다."}

    [모범 답안 예시 3 — 비영어 어원(그리스어) + 은유적 전이]
    입력: daemon
    return_term_entry input:
    {"keyword":"daemon","aliases":["데몬","demon"],"category":"기타","summary":"백그라운드에서 지속 실행되는 프로세스","etymology":"그리스어 δαίμων(daimōn)에서 유래. 본래 '신과 인간 사이의 중개 영혼'을 뜻하는 종교·철학 용어로, 사람 눈에 보이지 않으면서 일을 대신 처리하는 존재를 가리켰다.","namingReason":"1963년 MIT의 Project MAC에서 Maxwell의 악마(Maxwell's demon) 사고실험에 영감을 받아 명명되었다. 사용자 상호작용 없이 시스템 뒤편에서 스스로 작업을 처리하는 프로세스를 '보이지 않는 중개자'라는 원의미에 빗댄 은유적 전이다. Unix 관습에 따라 프로세스 이름 끝에 'd'를 붙인다(httpd, sshd)."}
    """
}
