import Foundation

/// 번들 DB와 AI 응답이 공유하는 용어 데이터 전송 객체
struct TermEntry: Codable, Hashable {
    let keyword: String
    let aliases: [String]
    let summary: String
    let etymology: String
    let namingReason: String
}
