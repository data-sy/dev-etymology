import Combine
import Foundation
import SwiftUI

/// 검색 화면 뷰 모델
/// - TermServiceProtocol에만 의존 (@Environment 주입을 통해 View가 세팅)
/// - 자동완성은 300ms 디바운스 후 호출, 최소 1자 이상
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [TermEntry] = []
    @Published var recent: [SearchHistory] = []

    /// 외부(View)에서 주입
    var termService: (any TermServiceProtocol)?

    /// 자동완성 디바운스 Task — 연타 시 cancel 후 재할당하여 레이스 방지
    private var currentSearchTask: Task<Void, Never>?

    deinit {
        currentSearchTask?.cancel()
    }

    /// 입력 변경 시 호출 — 디바운스 후 자동완성 조회
    func onQueryChanged(_ newValue: String) {
        currentSearchTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        currentSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Constants.autocompleteDebounceMs) * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            let results = self.termService?.autocomplete(prefix: trimmed) ?? []
            guard !Task.isCancelled else { return }
            self.suggestions = results
        }
    }

    /// 최근 검색 목록 갱신
    func refreshRecent() {
        recent = termService?.recentSearches(limit: Constants.recentSearchLimit) ?? []
    }

    /// 검색 확정 시 정규화된 키워드 반환 (빈 문자열이면 nil)
    func commit() -> String? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return normalized
    }
}
