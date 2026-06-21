import XCTest
@testable import DevEtym

/// DetailViewModel 로딩 UX(단계 메시지·최소 표시 시간) 및 fetch 분기 테스트
@MainActor
final class DetailViewModelTests: XCTestCase {

    private var viewModel: DetailViewModel!
    private var mock: MockTermService!

    override func setUp() async throws {
        viewModel = DetailViewModel()
        mock = MockTermService()
        viewModel.termService = mock
    }

    override func tearDown() async throws {
        viewModel.cancelLoading()
        viewModel = nil
        mock = nil
    }

    // MARK: - 로딩 단계 메시지/정당화 텍스트

    func test_loadingPhase_messages_areDistinctAndOrdered() {
        let phases = DetailViewModel.LoadingPhase.allCases
        XCTAssertEqual(phases, [.searching, .organizing, .finishing])

        XCTAssertEqual(DetailViewModel.LoadingPhase.searching.message, "어원을 찾고 있어요")
        XCTAssertEqual(DetailViewModel.LoadingPhase.organizing.message, "어원을 정리하고 있어요")
        XCTAssertEqual(DetailViewModel.LoadingPhase.finishing.message, "마무리하고 있어요")

        // 세 메시지는 서로 달라야 함 (단계 전환이 사용자에게 인지되도록)
        let messages = Set(phases.map(\.message))
        XCTAssertEqual(messages.count, 3)
    }

    func test_loadingPhase_justification_explainsWhyWaiting() {
        for phase in DetailViewModel.LoadingPhase.allCases {
            XCTAssertTrue(phase.justification.contains("AI"),
                          "정당화 텍스트는 왜 기다리는지(AI 분석) 설명해야 함")
        }
    }

    func test_loadingPhase_startTimes_areMonotonicallyIncreasing() {
        XCTAssertEqual(DetailViewModel.LoadingPhase.searching.startNanoseconds, 0)
        XCTAssertLessThan(DetailViewModel.LoadingPhase.searching.startNanoseconds,
                          DetailViewModel.LoadingPhase.organizing.startNanoseconds)
        XCTAssertLessThan(DetailViewModel.LoadingPhase.organizing.startNanoseconds,
                          DetailViewModel.LoadingPhase.finishing.startNanoseconds)
    }

    // MARK: - 초기 상태

    func test_initialState_isLoadingSearching() {
        XCTAssertEqual(viewModel.loadingPhase, .searching)
        if case .loading = viewModel.state {} else {
            XCTFail("초기 상태는 .loading 이어야 함")
        }
    }

    // MARK: - fetch 성공 → loaded 전환

    func test_load_success_transitionsToLoaded() async {
        viewModel.minimumLoadingNanoseconds = 0
        mock.fetchResult = .found(MockTermService.sampleEntries[0], source: "ai")

        viewModel.load(keyword: "mutex")
        await waitUntilLoaded(timeout: 1.0)

        guard case .loaded(.found(let entry, let source)) = viewModel.state else {
            return XCTFail("fetch 성공 시 .loaded(.found) 이어야 함")
        }
        XCTAssertEqual(entry.keyword, "mutex")
        XCTAssertEqual(source, "ai")
    }

    // MARK: - 최소 표시 시간 (캐시 hit 깜빡임 방지)

    func test_load_fastResult_holdsLoadingForMinimumDuration() async {
        // 즉시 반환되는 fetch라도 최소 표시 시간 동안은 .loading 유지
        viewModel.minimumLoadingNanoseconds = 300 * 1_000_000 // 300ms
        mock.fetchDelayNanoseconds = 0
        mock.fetchResult = .found(MockTermService.sampleEntries[0], source: "bundle")

        viewModel.load(keyword: "mutex")

        // 100ms 시점 — 아직 최소 표시 시간 내이므로 .loading
        try? await Task.sleep(nanoseconds: 100 * 1_000_000)
        if case .loaded = viewModel.state {
            XCTFail("최소 표시 시간(300ms) 내에는 .loading 이어야 함")
        }

        // 최소 표시 시간 경과 후 — .loaded
        await waitUntilLoaded(timeout: 1.0)
        if case .loaded = viewModel.state {} else {
            XCTFail("최소 표시 시간 경과 후 .loaded 여야 함")
        }
    }

    // MARK: - 에러 → errorMessage

    func test_load_failure_setsErrorMessage() async {
        viewModel.minimumLoadingNanoseconds = 0
        mock.fetchError = ClaudeAPIError.timeout

        viewModel.load(keyword: "mutex")
        await waitUntil(timeout: 1.0) { self.viewModel.errorMessage != nil }

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - 헬퍼

    private func waitUntilLoaded(timeout: TimeInterval) async {
        await waitUntil(timeout: timeout) {
            if case .loaded = self.viewModel.state { return true }
            return false
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20 * 1_000_000)
        }
    }
}
