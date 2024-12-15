import MillerKit
import TSCUtility
import MillerKitGemini

public func fetchFromGPT(ctx: Context) -> ((LazyItem, String) -> AsyncStream<LazyItem>) {
    return { selectedItem, prompt in
        let massagedPrompt = """
Format your response in valid Markdown syntax. Liberally use headings. Machine will extrct an outline of it.
In particular, go very deep with the structure of the candidate's response.
Prefer use headings instead of bullet items. But include some non-heading text too. 

\(prompt)
"""
        return AsyncStream { cont in
            Task {
                do {
                    if let engine = ctx.engine {
                        for response in try await engine.build(key: FetchGPT(prompt: massagedPrompt.replacingOccurrences(of: "$title", with: selectedItem.name)), ctx).get().response {
                            for await elem in markdownToLazyItemWithOffset(markdown: response) {
                                cont.yield(elem.1)
                            }
                        }
                    } else {
                        // print("ENGINE NOT SET")
                    }
                } catch {
                    cont.yield(LazyItem("\(error)"))
                }
                cont.finish()
            }
        }
    }
}
