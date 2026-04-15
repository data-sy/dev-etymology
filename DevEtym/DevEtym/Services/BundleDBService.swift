import Foundation

/// 앱 번들에 내장된 terms.json을 메모리에 캐싱하여
/// 로컬 용어 검색과 자동완성을 제공하는 서비스
@MainActor
protocol BundleDBServiceProtocol {
    func search(keyword: String) -> TermEntry?
    func autocomplete(prefix: String) -> [TermEntry]
}

@MainActor
final class BundleDBService: BundleDBServiceProtocol {
    private let terms: [TermEntry]

    /// 앱 시작 시 1회 로드, 메모리 캐시
    /// 번들에서 파일을 찾지 못하거나 디코딩에 실패하면 빈 배열로 초기화
    nonisolated init(bundle: Bundle = .main, resourceName: String = "terms", resourceExtension: String = "json") {
        guard
            let url = bundle.url(forResource: resourceName, withExtension: resourceExtension),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([TermEntry].self, from: data)
        else {
            self.terms = []
            return
        }
        self.terms = decoded
    }

    /// 테스트/Preview용 주입 이니셜라이저
    nonisolated init(terms: [TermEntry]) {
        self.terms = terms
    }

    /// keyword + aliases 대소문자 무시 완전 매칭
    func search(keyword: String) -> TermEntry? {
        let normalized = keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        return terms.first { entry in
            entry.keyword.lowercased() == normalized
                || entry.aliases.contains(where: { $0.lowercased() == normalized })
        }
    }

    /// keyword prefix 매칭 (타이핑 중 자동완성용)
    func autocomplete(prefix: String) -> [TermEntry] {
        let normalized = prefix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return [] }
        return terms.filter { $0.keyword.lowercased().hasPrefix(normalized) }
    }
}
