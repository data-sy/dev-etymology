import XCTest

/// 실제 Claude API를 호출하는 통합 UI 테스트.
/// **반드시 `-only-testing:DevEtymUITests/AIIntegrationUITests` 필터와 함께 실행**할 것.
/// 전체 테스트(`xcodebuild test`)에 섞어 돌리면 매번 API 비용이 발생한다.
///
/// 실행:
/// xcodebuild test \
///   -project DevEtym.xcodeproj -scheme DevEtym \
///   -destination 'platform=iOS Simulator,name=iPhone 17' \
///   -only-testing:DevEtymUITests/AIIntegrationUITests
@MainActor
final class AIIntegrationUITests: XCTestCase {

    /// AI 응답이 돌아올 때까지의 여유 시간. extended thinking + 네트워크 포함.
    private let aiTimeout: TimeInterval = 60

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 테스트

    /// 번들에 없는 용어를 검색 → AI 경로로 정상 TermEntry 수신.
    /// tool_use(return_term_entry) + 파싱 + AI 뱃지 렌더까지 end-to-end 검증.
    func test_integration_validAITerm_showsDetailWithAIBadge() throws {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.textFields["용어 검색"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "검색 필드를 찾지 못함")
        searchField.tap()
        searchField.typeText("idempotent\n")

        // AI 생성 뱃지가 떠야 found + source=="ai" 상태임이 확정된다
        let aiBadge = app.staticTexts["이 설명은 AI가 생성한 결과입니다"]
        XCTAssertTrue(
            aiBadge.waitForExistence(timeout: aiTimeout),
            "AI 뱃지가 timeout 내에 나타나지 않음 (응답 실패 또는 다른 경로로 간 것)"
        )

        // 카테고리 뱃지: "카테고리 {동시성|자료구조|...}"로 시작하는 staticText 존재 확인
        let categoryPredicate = NSPredicate(format: "label BEGINSWITH %@", "카테고리 ")
        let categoryBadge = app.staticTexts.matching(categoryPredicate).firstMatch
        XCTAssertTrue(categoryBadge.exists, "카테고리 뱃지가 화면에 없음")

        attachScreenshot(name: "validAITerm-idempotent")
    }

    /// 번들에 없는 오타 입력 → AI가 POSSIBLE_TYPO 도구 호출 → 추천 버튼 렌더.
    func test_integration_possibleTypo_showsSuggestionButton() throws {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.textFields["용어 검색"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("mutx\n")

        // possibleTypo UI의 추천 버튼 accessibilityLabel은 "추천 용어 {x} 검색"
        // AI가 mutex로 교정해 줄 것으로 기대하지만, 다른 교정일 수도 있으므로 prefix로 매치
        let suggestionPredicate = NSPredicate(format: "label BEGINSWITH %@", "추천 용어 ")
        let suggestionButton = app.buttons.matching(suggestionPredicate).firstMatch
        XCTAssertTrue(
            suggestionButton.waitForExistence(timeout: aiTimeout),
            "possibleTypo 추천 버튼이 timeout 내에 나타나지 않음"
        )

        attachScreenshot(name: "possibleTypo-mutx")
    }

    /// 개발 용어가 아닌 입력 → AI가 NOT_DEV_TERM 도구 호출 → 안내 메시지 렌더.
    func test_integration_notDevTerm_showsGuidanceMessage() throws {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.textFields["용어 검색"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("weather\n")

        let message = app.staticTexts["개발 용어를 검색해주세요"]
        XCTAssertTrue(
            message.waitForExistence(timeout: aiTimeout),
            "notDevTerm 안내 메시지가 timeout 내에 나타나지 않음"
        )

        attachScreenshot(name: "notDevTerm-weather")
    }

    // MARK: - 유틸

    private func attachScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
