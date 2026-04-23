import Foundation
@testable import DevEtym

struct RecordedSearch: Equatable {
    let keyword: String
    let resultType: SearchResultType
}

struct RecordedError: Equatable {
    let keyword: String
    let errorType: AnalyticsErrorType
}

/// 단위 테스트용 AnalyticsServiceProtocol 구현.
/// Firebase에 실제 전송하지 않고 호출 내역을 배열에 기록한다.
/// consentGiven == false이면 실제 구현체와 동일하게 no-op 처리한다.
@MainActor
final class MockAnalyticsService: AnalyticsServiceProtocol {
    var consentGiven: Bool = true
    var recordedSearches: [RecordedSearch] = []
    var recordedErrors: [RecordedError] = []

    func logSearch(keyword: String, resultType: SearchResultType) {
        guard consentGiven else { return }
        recordedSearches.append(RecordedSearch(keyword: keyword, resultType: resultType))
    }

    func logError(keyword: String, errorType: AnalyticsErrorType) {
        guard consentGiven else { return }
        recordedErrors.append(RecordedError(keyword: keyword, errorType: errorType))
    }
}
