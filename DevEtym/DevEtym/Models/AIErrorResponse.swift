import Foundation

/// Claude API가 반환하는 오류 응답 포맷
/// - error: "NOT_DEV_TERM" 또는 "POSSIBLE_TYPO"
/// - suggestion: POSSIBLE_TYPO인 경우 추천 용어
struct AIErrorResponse: Codable {
    let error: String
    let suggestion: String?
}
