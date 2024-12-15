import Foundation
import NIOCore
import TSFCAS
import TSFFutures
import llbuild2fx
import llbuild2
import TSCBasic
import GoogleGenerativeAI
import MillerKit

public struct FetchGPTResult: Codable {
    public let response: [String]
}

extension FetchGPTResult: FXValue {}

public struct FetchGPT: AsyncFXKey, Encodable {
    public typealias ValueType = FetchGPTResult

    public static let version: Int = 4
    public static let versionDependencies: [FXVersioning.Type] = []
    
    let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
    
    public func computeValue(_ fi: FXFunctionInterface<Self>, _ ctx: Context) async throws -> FetchGPTResult {
        ctx.logger?.log(level: .critical, "[AI] Probing for this prompt: '\(prompt)'")

        let client = LLBCASFSClient(ctx.db)

        var res: [String] = []
        try await randomDelay()

        let candidates = try await ctx.ai!.generateContent(prompt).candidates

        if candidates.isEmpty {
            throw StringError("AI did not return any response")
        }
        for candidate in candidates {
            res.append(candidate.content.parts.map { $0.text ?? "<No text>" }.joined(separator: " "))
        }

        ctx.logger?.log(level: .critical, "[AI] \(res)")

        return FetchGPTResult(response: res)
    }
}

