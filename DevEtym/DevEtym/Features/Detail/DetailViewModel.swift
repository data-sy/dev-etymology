import Combine
import Foundation
import SwiftUI

/// 상세 화면 뷰 모델
/// - fetch 결과를 TermResult로 보관하고, throw되는 에러는 errorMessage로 Alert 표시
/// - currentSearchTask로 중복 fetch/재검색 레이스 방지
@MainActor
final class DetailViewModel: ObservableObject {
    @Published var state: State = .loading
    @Published var errorMessage: String?
    @Published var isBookmarked: Bool = false
    /// 로딩 중 표시할 단계 — 시간 분할로 진행되며 *체감* latency를 줄인다.
    @Published var loadingPhase: LoadingPhase = .searching

    enum State {
        case loading
        case loaded(TermResult)
    }

    /// 로딩 단계 — fetch는 단일 await라 실제 진행률을 알 수 없으므로 시간 기반으로 전환한다.
    /// 캐시/번들 hit은 즉시 반환되어 .searching 단계까지만 보이고 결과로 전환된다.
    enum LoadingPhase: CaseIterable {
        case searching   // 0s~
        case organizing  // ~2.5s
        case finishing   // ~5s

        /// 단계 전환 시각(나노초). load 시작 기준 경과 시간.
        var startNanoseconds: UInt64 {
            switch self {
            case .searching:  return 0
            case .organizing: return 2_500 * 1_000_000
            case .finishing:  return 5_000 * 1_000_000
            }
        }

        /// 사용자에게 보이는 단계 메시지
        var message: String {
            switch self {
            case .searching:  return "어원을 찾고 있어요"
            case .organizing: return "어원을 정리하고 있어요"
            case .finishing:  return "마무리하고 있어요"
            }
        }

        /// 왜 기다리는지 설명하는 정당화 텍스트
        var justification: String {
            "✦ AI가 어원을 분석하고 있어요"
        }
    }

    /// 캐시/번들 hit 즉시 반환 시 스피너가 깜빡이는 것을 막기 위한 최소 표시 시간(나노초).
    /// 테스트에서 0으로 낮춰 타이밍 의존을 제거할 수 있도록 주입 가능하게 둔다.
    var minimumLoadingNanoseconds: UInt64 = 350 * 1_000_000

    var termService: (any TermServiceProtocol)?

    private var currentSearchTask: Task<Void, Never>?
    private var phaseTask: Task<Void, Never>?
    private var loadedKeyword: String?

    deinit {
        currentSearchTask?.cancel()
        phaseTask?.cancel()
    }

    /// View가 사라질 때 호출 — 진행 중인 fetch 취소
    func cancelLoading() {
        currentSearchTask?.cancel()
        phaseTask?.cancel()
    }

    /// 주어진 keyword로 fetch 수행 (중복 호출 시 기존 Task cancel)
    func load(keyword: String) {
        // 동일 keyword 재진입 시 중복 호출 방지
        if case .loaded = state, loadedKeyword == keyword { return }

        currentSearchTask?.cancel()
        phaseTask?.cancel()
        state = .loading
        loadingPhase = .searching
        errorMessage = nil
        startPhaseProgression()

        currentSearchTask = Task { [weak self] in
            guard let self, let service = self.termService else { return }
            let startedAt = DispatchTime.now().uptimeNanoseconds
            do {
                let result = try await service.fetch(keyword: keyword)
                guard !Task.isCancelled else { return }
                await self.enforceMinimumLoading(since: startedAt)
                guard !Task.isCancelled else { return }
                self.phaseTask?.cancel()
                self.loadedKeyword = keyword
                self.state = .loaded(result)
                self.isBookmarked = self.computeBookmarkStatus(for: result, service: service)
            } catch {
                guard !Task.isCancelled else { return }
                self.phaseTask?.cancel()
                self.errorMessage = Self.message(for: error)
            }
        }
    }

    /// 시간 기반으로 loadingPhase를 .searching → .organizing → .finishing 전환
    private func startPhaseProgression() {
        phaseTask = Task { [weak self] in
            guard let self else { return }
            // .searching은 즉시 적용된 상태이므로 이후 단계만 직전 단계와의 간격만큼 대기 후 전환
            var previousStart: UInt64 = LoadingPhase.searching.startNanoseconds
            for phase in LoadingPhase.allCases where phase != .searching {
                try? await Task.sleep(nanoseconds: phase.startNanoseconds - previousStart)
                guard !Task.isCancelled else { return }
                self.loadingPhase = phase
                previousStart = phase.startNanoseconds
            }
        }
    }

    /// 결과가 최소 표시 시간보다 일찍 도착하면 남은 시간만큼 대기 (깜빡임 방지)
    private func enforceMinimumLoading(since startedAt: UInt64) async {
        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
        guard elapsed < minimumLoadingNanoseconds else { return }
        try? await Task.sleep(nanoseconds: minimumLoadingNanoseconds - elapsed)
    }

    /// 북마크 토글 — 성공 시 isBookmarked 갱신
    func toggleBookmark() {
        guard let service = termService,
              case .loaded(.found(let entry, _)) = state else { return }
        do {
            isBookmarked = try service.toggleBookmark(for: entry)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - 에러 메시지 변환

    private static func message(for error: Error) -> String {
        if let apiError = error as? ClaudeAPIError {
            switch apiError {
            case .invalidAPIKey:
                return "API 키 설정이 필요합니다"
            case .timeout:
                return "요청 시간이 초과되었습니다. 다시 시도해주세요"
            case .networkError(let underlying):
                if let urlError = underlying as? URLError,
                   urlError.code == .notConnectedToInternet {
                    return "인터넷 연결을 확인해주세요"
                }
                return "네트워크 연결이 불안정합니다. 다시 시도해주세요"
            case .invalidResponse:
                return "응답을 처리할 수 없습니다. 다시 시도해주세요"
            case .notDevTerm, .possibleTypo:
                // 이 두 케이스는 서비스 레이어에서 TermResult로 변환되어야 함
                return "오류가 발생했습니다. 다시 시도해주세요"
            }
        }
        return "오류가 발생했습니다. 문제가 계속되면 제보해주세요"
    }

    // MARK: - 북마크 상태 조회

    private func computeBookmarkStatus(
        for result: TermResult,
        service: any TermServiceProtocol
    ) -> Bool {
        guard case .found(let entry, _) = result else { return false }
        let keyword = entry.keyword.lowercased()
        return service.bookmarkedTerms().contains { $0.keyword == keyword }
    }
}

