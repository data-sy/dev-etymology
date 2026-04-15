import Foundation
import SwiftData

/// AI 응답 캐시 및 북마크를 위한 SwiftData 모델
@Model
final class Term {
    #Unique<Term>([\.keyword])
    #Index<Term>([\.isBookmarked], [\.createdAt], [\.category])

    var keyword: String
    var aliases: [String]
    var category: String
    var summary: String
    var etymology: String
    var namingReason: String
    /// "bundle" | "ai"
    var source: String
    var isBookmarked: Bool
    var createdAt: Date

    init(
        keyword: String,
        aliases: [String] = [],
        category: String,
        summary: String,
        etymology: String,
        namingReason: String,
        source: String = "ai",
        isBookmarked: Bool = false
    ) {
        self.keyword = keyword
        self.aliases = aliases
        self.category = category
        self.summary = summary
        self.etymology = etymology
        self.namingReason = namingReason
        self.source = source
        self.isBookmarked = isBookmarked
        self.createdAt = .now
    }
}

// MARK: - TermEntry 변환

extension Term {
    /// TermEntry → Term 변환 (aliases + category 포함 필수)
    convenience init(from entry: TermEntry, source: String, isBookmarked: Bool = false) {
        self.init(
            keyword: entry.keyword.lowercased(),
            aliases: entry.aliases,
            category: entry.category,
            summary: entry.summary,
            etymology: entry.etymology,
            namingReason: entry.namingReason,
            source: source,
            isBookmarked: isBookmarked
        )
    }

    /// Term → TermEntry 역변환
    func toEntry() -> TermEntry {
        TermEntry(
            keyword: keyword,
            aliases: aliases,
            category: category,
            summary: summary,
            etymology: etymology,
            namingReason: namingReason
        )
    }
}
