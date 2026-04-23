import Foundation

/// 검색 결과 유형 — Firebase "result_type" 파라미터의 값 집합
enum SearchResultType: String {
    case bundleHit = "bundle_hit"
    case aiGenerated = "ai_generated"
    case notDevTerm = "not_dev_term"
    case possibleTypo = "possible_typo"
}

/// Claude API 오류 유형 — Firebase "error_type" 파라미터의 값 집합
enum AnalyticsErrorType: String {
    case timeout
    case invalidResponse = "invalid_response"
    case networkError = "network_error"
    case invalidAPIKey = "invalid_api_key"
}

/// 사용자 동의 여부에 따라 Firebase Analytics 이벤트를 기록하는 서비스
///
/// ViewModel/UI가 Firebase를 직접 import하지 않도록 추상화한다.
/// 실제 Firebase 의존은 AnalyticsService 구현체에만 존재한다.
@MainActor
protocol AnalyticsServiceProtocol {
    /// 사용자 동의 여부. UserDefaults에 퍼시스트되며 false일 때 모든 log는 no-op
    var consentGiven: Bool { get set }

    /// 검색 이벤트 기록
    func logSearch(keyword: String, resultType: SearchResultType)

    /// 검색 중 Claude API 오류 이벤트 기록
    func logError(keyword: String, errorType: AnalyticsErrorType)
}
