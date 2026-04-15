import Foundation
import SwiftData

/// 검색 기록 SwiftData 모델
@Model
final class SearchHistory {
    #Unique<SearchHistory>([\.keyword])
    #Index<SearchHistory>([\.searchedAt])

    var keyword: String
    var searchedAt: Date

    init(keyword: String) {
        self.keyword = keyword
        self.searchedAt = .now
    }
}
