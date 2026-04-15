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

    enum State {
        case loading
        case loaded(TermResult)
    }

    var termService: (any TermServiceProtocol)?

    private var currentSearchTask: Task<Void, Never>?
    private var loadedKeyword: String?

    deinit {
        currentSearchTask?.cancel()
    }

    /// View가 사라질 때 호출 — 진행 중인 fetch 취소
    func cancelLoading() {
        currentSearchTask?.cancel()
    }

    /// 주어진 keyword로 fetch 수행 (중복 호출 시 기존 Task cancel)
    func load(keyword: String) {
        // 동일 keyword 재진입 시 중복 호출 방지
        if case .loaded = state, loadedKeyword == keyword { return }

        currentSearchTask?.cancel()
        state = .loading
        errorMessage = nil

        currentSearchTask = Task { [weak self] in
            guard let self, let service = self.termService else { return }
            do {
                let result = try await service.fetch(keyword: keyword)
                guard !Task.isCancelled else { return }
                self.loadedKeyword = keyword
                self.state = .loaded(result)
                self.isBookmarked = self.computeBookmarkStatus(for: result, service: service)
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = Self.message(for: error)
            }
        }
    }

    /// 북마크 토글 — 성공 시 isBookmarked 갱신
    func toggleBookmark() {
        guard let service = termService,
              case .loaded(.found(let entry)) = state else { return }
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
        guard case .found(let entry) = result else { return false }
        let keyword = entry.keyword.lowercased()
        return service.bookmarkedTerms().contains { $0.keyword == keyword }
    }
}

