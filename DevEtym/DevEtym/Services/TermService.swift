import Foundation
import SwiftData

/// 검색, 북마크, 히스토리를 통합 오케스트레이션하는 서비스
///
/// 모든 ViewModel은 TermServiceProtocol에만 의존한다.
/// ViewModel은 modelContext, BundleDBService, ClaudeAPIService를 직접 참조하지 않는다.
@MainActor
final class TermService: TermServiceProtocol {
    private let modelContext: ModelContext
    private let bundleDBService: BundleDBServiceProtocol
    private let claudeAPIService: ClaudeAPIServiceProtocol

    init(
        modelContext: ModelContext,
        bundleDBService: BundleDBServiceProtocol = BundleDBService(),
        claudeAPIService: ClaudeAPIServiceProtocol = ClaudeAPIService()
    ) {
        self.modelContext = modelContext
        self.bundleDBService = bundleDBService
        self.claudeAPIService = claudeAPIService
    }

    // MARK: - 검색

    func fetch(keyword: String) async throws -> TermResult {
        let normalized = normalize(keyword)
        guard !normalized.isEmpty else { return .notDevTerm }

        // 1) 번들 DB
        if let entry = bundleDBService.search(keyword: normalized) {
            try upsertSearchHistory(keyword: normalized)
            return .found(entry)
        }

        // 2) SwiftData 캐시 — AI 응답으로 저장된 항목만 캐시로 취급
        //    (source == "bundle"은 북마크 용도로만 저장된 번들 항목이므로 캐시에서 제외)
        if let cached = findTerm(keyword: normalized), cached.source == "ai" {
            try upsertSearchHistory(keyword: normalized)
            return .found(cached.toEntry())
        }

        // 3) Claude AI
        do {
            let entry = try await claudeAPIService.generate(keyword: normalized)
            upsertTerm(entry: entry, source: "ai")
            try upsertSearchHistory(keyword: normalized)
            return .found(entry)
        } catch ClaudeAPIError.notDevTerm {
            return .notDevTerm
        } catch ClaudeAPIError.possibleTypo(let suggestion) {
            return .possibleTypo(suggestion)
        } catch {
            throw error
        }
    }

    func autocomplete(prefix: String) -> [TermEntry] {
        bundleDBService.autocomplete(prefix: prefix)
    }

    // MARK: - 북마크

    func toggleBookmark(for entry: TermEntry) throws -> Bool {
        let key = entry.keyword.lowercased()
        if let existing = findTerm(keyword: key) {
            existing.isBookmarked.toggle()
            try modelContext.save()
            return existing.isBookmarked
        } else {
            let term = Term(from: entry, source: "bundle", isBookmarked: true)
            modelContext.insert(term)
            try modelContext.save()
            return true
        }
    }

    func bookmarkedTerms() -> [Term] {
        let descriptor = FetchDescriptor<Term>(
            predicate: #Predicate { $0.isBookmarked == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - 히스토리

    func recentSearches(limit: Int) -> [SearchHistory] {
        var descriptor = FetchDescriptor<SearchHistory>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func deleteSearchHistory(_ keyword: String) throws {
        let key = normalize(keyword)
        let descriptor = FetchDescriptor<SearchHistory>(
            predicate: #Predicate { $0.keyword == key }
        )
        let results = try modelContext.fetch(descriptor)
        for item in results {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func clearAllSearchHistory() throws {
        let descriptor = FetchDescriptor<SearchHistory>()
        let all = try modelContext.fetch(descriptor)
        for item in all {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    // MARK: - 내부 헬퍼

    private func normalize(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func findTerm(keyword: String) -> Term? {
        let key = keyword
        let descriptor = FetchDescriptor<Term>(
            predicate: #Predicate { $0.keyword == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// 동일 keyword가 있으면 필드 업데이트 (isBookmarked, source 보존), 없으면 insert
    private func upsertTerm(entry: TermEntry, source: String) {
        let key = entry.keyword.lowercased()
        if let existing = findTerm(keyword: key) {
            existing.aliases = entry.aliases
            existing.summary = entry.summary
            existing.etymology = entry.etymology
            existing.namingReason = entry.namingReason
            // isBookmarked, source는 보존
        } else {
            let term = Term(from: entry, source: source, isBookmarked: false)
            modelContext.insert(term)
        }
        try? modelContext.save()
    }

    /// 동일 keyword 존재 시 searchedAt만 갱신, 없으면 insert
    private func upsertSearchHistory(keyword: String) throws {
        let key = keyword
        let descriptor = FetchDescriptor<SearchHistory>(
            predicate: #Predicate { $0.keyword == key }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.searchedAt = .now
        } else {
            modelContext.insert(SearchHistory(keyword: keyword))
        }
        try modelContext.save()
    }
}
