import Foundation

/// 용어 검색 결과 분기
enum TermResult {
    case found(TermEntry)
    case notDevTerm
    case possibleTypo(String)
}
