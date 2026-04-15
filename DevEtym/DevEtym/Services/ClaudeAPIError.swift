import Foundation

/// Claude API 호출 중 발생할 수 있는 에러 케이스
/// - Agent B(UI)가 분기 처리에 사용하는 타입을 먼저 분리하여 정의한다
/// - Agent A(Services)가 ClaudeAPIService를 구현할 때 이 타입을 그대로 사용
enum ClaudeAPIError: Error {
    case invalidAPIKey
    case timeout
    case networkError(Error)
    case invalidResponse
    case notDevTerm
    case possibleTypo(suggestion: String)
}
