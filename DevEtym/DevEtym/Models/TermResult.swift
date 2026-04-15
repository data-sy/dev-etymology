import Foundation

/// 용어 검색 결과 분기
///
/// `.found`의 `source`는 결과 출처를 나타낸다 — `"bundle"`(번들 DB), `"ai"`(Claude 생성).
/// UI는 source가 `"ai"`일 때만 AI 생성 뱃지를 표시한다.
enum TermResult {
    case found(TermEntry, source: String)
    case notDevTerm
    case possibleTypo(String)
}
