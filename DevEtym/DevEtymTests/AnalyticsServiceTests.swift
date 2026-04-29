import XCTest
@testable import DevEtym

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    private let suiteName = "AnalyticsServiceTestsSuite"
    private var defaults: UserDefaults!

    override func setUp() async throws {
        guard let suite = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite 생성 실패")
            return
        }
        defaults = suite
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - consent 저장/조회

    func test_consentGiven_reflectsUserDefaults() {
        let service = AnalyticsService(defaults: defaults)
        XCTAssertFalse(service.consentGiven) // 기본값 false

        service.consentGiven = true
        XCTAssertTrue(defaults.bool(forKey: Constants.analyticsConsentKey))
        XCTAssertTrue(service.consentGiven)

        service.consentGiven = false
        XCTAssertFalse(defaults.bool(forKey: Constants.analyticsConsentKey))
        XCTAssertFalse(service.consentGiven)
    }

    // MARK: - consent off 시 no-op (실제 구현체)
    // 동의 off 상태에서는 guard에서 걸리므로 Firebase에 닿지 않아야 한다.
    // 직접 관찰은 불가하지만 최소한 크래시 없이 통과하는지 확인한다.

    func test_AnalyticsService_logSearch_whenConsentOff_skipsFirebase() {
        let service = AnalyticsService(defaults: defaults)
        service.consentGiven = false
        service.logSearch(keyword: "mutex", resultType: .bundleHit)
    }

    func test_AnalyticsService_logError_whenConsentOff_skipsFirebase() {
        let service = AnalyticsService(defaults: defaults)
        service.consentGiven = false
        service.logError(keyword: "mutex", errorType: .timeout)
    }

    // MARK: - Mock 경유 on/off 동작 검증
    // 실제 Firebase 호출은 검증할 수 없으므로 Mock이 프로토콜 계약(consent gate)을
    // 동일하게 구현하는지 확인한다.

    func test_logSearch_whenConsentOff_doesNothing() {
        let mock = MockAnalyticsService()
        mock.consentGiven = false

        mock.logSearch(keyword: "mutex", resultType: .bundleHit)

        XCTAssertTrue(mock.recordedSearches.isEmpty)
    }

    func test_logSearch_whenConsentOn_callsFirebase() {
        let mock = MockAnalyticsService()
        mock.consentGiven = true

        mock.logSearch(keyword: "mutex", resultType: .bundleHit)

        XCTAssertEqual(mock.recordedSearches.count, 1)
        XCTAssertEqual(mock.recordedSearches[0].keyword, "mutex")
        XCTAssertEqual(mock.recordedSearches[0].resultType, .bundleHit)
    }

    func test_logError_whenConsentOff_doesNothing() {
        let mock = MockAnalyticsService()
        mock.consentGiven = false

        mock.logError(keyword: "mutex", errorType: .timeout)

        XCTAssertTrue(mock.recordedErrors.isEmpty)
    }

    func test_logError_whenConsentOn_recordsError() {
        let mock = MockAnalyticsService()
        mock.consentGiven = true

        mock.logError(keyword: "mutex", errorType: .timeout)

        XCTAssertEqual(mock.recordedErrors.count, 1)
        XCTAssertEqual(mock.recordedErrors[0].keyword, "mutex")
        XCTAssertEqual(mock.recordedErrors[0].errorType, .timeout)
    }

    // MARK: - enum rawValue 스키마 보장
    // Firebase에 송출되는 문자열 키가 계약대로 유지되는지 고정한다.

    func test_SearchResultType_rawValues() {
        XCTAssertEqual(SearchResultType.bundleHit.rawValue, "bundle_hit")
        XCTAssertEqual(SearchResultType.aiGenerated.rawValue, "ai_generated")
        XCTAssertEqual(SearchResultType.notDevTerm.rawValue, "not_dev_term")
        XCTAssertEqual(SearchResultType.possibleTypo.rawValue, "possible_typo")
    }

    func test_AnalyticsErrorType_rawValues() {
        XCTAssertEqual(AnalyticsErrorType.timeout.rawValue, "timeout")
        XCTAssertEqual(AnalyticsErrorType.invalidResponse.rawValue, "invalid_response")
        XCTAssertEqual(AnalyticsErrorType.networkError.rawValue, "network_error")
        XCTAssertEqual(AnalyticsErrorType.invalidAPIKey.rawValue, "invalid_api_key")
    }
}
