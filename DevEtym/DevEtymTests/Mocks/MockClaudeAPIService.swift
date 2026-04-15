import Foundation
@testable import DevEtym

final class MockClaudeAPIService: ClaudeAPIServiceProtocol {
    var result: Result<TermEntry, Error> = .failure(ClaudeAPIError.invalidResponse)
    var generateCalls: [String] = []

    func generate(keyword: String) async throws -> TermEntry {
        generateCalls.append(keyword)
        switch result {
        case .success(let entry):
            return entry
        case .failure(let error):
            throw error
        }
    }
}
