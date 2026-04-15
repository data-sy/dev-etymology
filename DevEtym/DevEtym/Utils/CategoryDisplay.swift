import Foundation

/// 카테고리 한글 코드(서비스 데이터의 정식 값)를 UI 표시용 영문 이름과 페어로 매핑한다
/// - 6개 고정 집합: 동시성 / 자료구조 / 네트워크 / DB / 패턴 / 기타
/// - 6개 외 값이 들어와도 안전하게 그대로 한글 코드만 반환
enum CategoryDisplay {
    /// "동시성" → "동시성 · Concurrency"
    static func formatted(_ category: String) -> String {
        if let english = englishName[category] {
            return "\(category) · \(english)"
        }
        return category
    }

    private static let englishName: [String: String] = [
        "동시성": "Concurrency",
        "자료구조": "Data Structure",
        "네트워크": "Network",
        "DB": "Database",
        "패턴": "Pattern",
        "기타": "General"
    ]
}
