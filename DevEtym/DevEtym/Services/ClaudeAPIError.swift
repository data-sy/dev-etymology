import Foundation

/// Claude API 호출 중 발생할 수 있는 에러 케이스
/// - Service 레이어가 throw하고, ViewModel이 분기 처리에 사용
enum ClaudeAPIError: Error, Equatable {
    case invalidAPIKey
    case timeout
    case networkError(Error)
    case invalidResponse
    case notDevTerm
    case possibleTypo(suggestion: String)

    static func == (lhs: ClaudeAPIError, rhs: ClaudeAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAPIKey, .invalidAPIKey),
             (.timeout, .timeout),
             (.invalidResponse, .invalidResponse),
             (.notDevTerm, .notDevTerm):
            return true
        case let (.possibleTypo(a), .possibleTypo(b)):
            return a == b
        case let (.networkError(a), .networkError(b)):
            return (a as NSError) == (b as NSError)
        default:
            return false
        }
    }
}
