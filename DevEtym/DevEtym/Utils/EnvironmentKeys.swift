import SwiftUI

/// SwiftUI .environment()에 프로토콜 타입을 직접 전달하면 컴파일 오류가 발생하므로
/// 커스텀 EnvironmentKey를 통해 TermServiceProtocol을 주입한다
private struct TermServiceKey: EnvironmentKey {
    @MainActor
    static let defaultValue: any TermServiceProtocol = PlaceholderTermService()
}

private struct AnalyticsServiceKey: EnvironmentKey {
    @MainActor
    static let defaultValue: any AnalyticsServiceProtocol = PlaceholderAnalyticsService()
}

extension EnvironmentValues {
    var termService: any TermServiceProtocol {
        get { self[TermServiceKey.self] }
        set { self[TermServiceKey.self] = newValue }
    }

    var analyticsService: any AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

/// 기본값용 더미 — 실제 사용 시 DevEtymApp에서 실제 TermService로 교체
/// Preview에서는 MockTermService로 교체
@MainActor
private final class PlaceholderTermService: TermServiceProtocol {
    func fetch(keyword: String) async throws -> TermResult { .notDevTerm }
    func autocomplete(prefix: String) -> [TermEntry] { [] }
    func toggleBookmark(for entry: TermEntry) throws -> Bool { false }
    func bookmarkedTerms() -> [Term] { [] }
    func recentSearches(limit: Int) -> [SearchHistory] { [] }
    func deleteSearchHistory(_ keyword: String) throws {}
    func clearAllSearchHistory() throws {}
}

/// Firebase 없이 동작하는 더미 — Preview/기본값/테스트에서 no-op
/// TermService init의 기본 파라미터로도 쓰이므로 internal 접근과 nonisolated init을 사용
@MainActor
final class PlaceholderAnalyticsService: AnalyticsServiceProtocol {
    var consentGiven: Bool = false
    nonisolated init() {}
    func logSearch(keyword: String, resultType: SearchResultType) {}
    func logError(keyword: String, errorType: AnalyticsErrorType) {}
    func appInstanceID() async -> String? { nil }
}
