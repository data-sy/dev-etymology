import Foundation

/// 번들 DB와 AI 응답이 공유하는 용어 데이터 전송 객체
struct TermEntry: Codable, Hashable {
    let keyword: String
    let aliases: [String]
    let category: String
    let summary: String
    let etymology: String
    let namingReason: String
}

extension TermEntry {
    /// 허용되는 카테고리 값 (번들 DB·AI 응답 공통 고정 집합)
    static let allowedCategories: [String] = [
        "동시성", "자료구조", "네트워크", "DB", "패턴", "기타"
    ]
}
