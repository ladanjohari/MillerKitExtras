import Foundation
import NIOCore
import TSFCAS
import TSFFutures
import llbuild2fx
import llbuild2
import TSCBasic

public struct FetchHTTPResult: Codable {
    let data: Data
}

extension FetchHTTPResult: FXValue {}

public struct FetchHTTP: AsyncFXKey, Encodable {
    public typealias ValueType = FetchHTTPResult

    public static let version: Int = 5
    public static let versionDependencies: [FXVersioning.Type] = []
    
    let url: URL

    public init(url: URL) {
        self.url = url
    }
    
    public func computeValue(_ fi: FXFunctionInterface<Self>, _ ctx: Context) async throws -> FetchHTTPResult {
        let client = LLBCASFSClient(ctx.db)

        var request = URLRequest(url:url)
        request.httpMethod = "GET"
        // If authentication is required, add the token to the headers
        request.addValue(ctx.freefeedKey!, forHTTPHeaderField: "X-Authentication-Token")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        return FetchHTTPResult(data: data)
    }
}
