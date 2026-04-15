import Foundation
@testable import DevEtym

@MainActor
final class MockBundleDBService: BundleDBServiceProtocol {
    var terms: [TermEntry]
    var searchCalls: [String] = []
    var autocompleteCalls: [String] = []

    init(terms: [TermEntry] = []) {
        self.terms = terms
    }

    func search(keyword: String) -> TermEntry? {
        searchCalls.append(keyword)
        let normalized = keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        return terms.first { entry in
            entry.keyword.lowercased() == normalized
                || entry.aliases.contains(where: { $0.lowercased() == normalized })
        }
    }

    func autocomplete(prefix: String) -> [TermEntry] {
        autocompleteCalls.append(prefix)
        let normalized = prefix.lowercased()
        guard !normalized.isEmpty else { return [] }
        return terms.filter { $0.keyword.lowercased().hasPrefix(normalized) }
    }
}
