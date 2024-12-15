import MillerKit

public protocol SiteGeneratorDelegate {
    func itemToHTML(_: LazyItem) async throws -> String
    func summarizeGroup(_: [LazyItem]) async throws -> String
}
