import Foundation
import FirebaseAnalytics

/// Firebase Analytics를 사용해 검색/오류 이벤트를 기록하는 구현체
///
/// consentGiven == false이면 모든 log 메서드는 즉시 return 하므로
/// Firebase로는 어떤 데이터도 전송되지 않는다 (PIPA 옵트인 정책).
@MainActor
final class AnalyticsService: AnalyticsServiceProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 동의 값은 UserDefaults에 퍼시스트. 최초값 false (옵트인 기본)
    var consentGiven: Bool {
        get { defaults.bool(forKey: Constants.analyticsConsentKey) }
        set { defaults.set(newValue, forKey: Constants.analyticsConsentKey) }
    }

    func logSearch(keyword: String, resultType: SearchResultType) {
        guard consentGiven else { return }
        Analytics.logEvent("search", parameters: [
            "keyword": keyword,
            "result_type": resultType.rawValue
        ])
    }

    func logError(keyword: String, errorType: AnalyticsErrorType) {
        guard consentGiven else { return }
        Analytics.logEvent("search_error", parameters: [
            "keyword": keyword,
            "error_type": errorType.rawValue
        ])
    }

    func appInstanceID() async -> String? {
        await Analytics.appInstanceID()
    }
}
