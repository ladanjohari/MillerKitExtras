import Foundation
import llbuild2fx
import TSFCASFileTree
import TSCBasic
import CryptoKit
import MillerKit
import MillerKitGemini

extension Date {
    public func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date.now)
    }
}

public struct MyStaticSiteGenerator: SiteGeneratorDelegate {
    let ctx: Context

    public init(ctx: Context) {
        self.ctx = ctx
    }

    public func itemToHTML(_ item: MillerKit.LazyItem) async throws -> String {
        let decoder = JSONDecoder()
        let post = try? decoder.decode(
            GPTOutput.self,
            from: (item.staticAttributes.first { $0.name == "GPT" }?.value.jsonValue ?? "").data(using: .utf8)!
        )

        let checksum = SHA256.hash(data: Data(item.name.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let title = post?.title ?? "no-title"
        let summary = post?.summary ?? "no-summary"
        let summaryClass = post?.summary == nil ? "class=no-summary" : ""
        let interesting = Int(post?.quality ?? -1)

        if interesting < 300 || post?.pinned != true {
            // return ""
        }

        let pinned = post?.pinned ?? false
        let tags = post?.tags ?? []

        var images: [String] = [] // (post?.imageURLs ?? [])
//        if let subItems = item.subItems {
//            for await subItem in subItems(ctx) {
//                images += extractImageURLs(subItem.name)
//            }
//        }
        if let cover = item.staticAttributes.first { $0.name == "cover" }?.value.stringValue {
            images.append(cover)
        }

        return """
<div class='item nima interesting-\(interesting) \(pinned ? "pinned" : "")'>
\(images.map { if $0.contains("youtube") {
"""
<p><iframe style="width: 100%; min-height: 315px" src="\($0)" title="" frameBorder="0"   allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"  allowFullScreen></iframe></p>
"""
} else {
"<img src=\"\($0)\" style='max-width: 100%;' />"
} }.joined())
<div class='title'>
<div \(summaryClass)>
<p><b><a href=\"\(checksum).html\"><b>\(title)</a></b></p>

<br />

<footnote>\(item.staticCreatedAt()?.timeAgoDisplay() ?? "")</footnote></b>
<blockquote><pre>\(summary)</pre></blockquote>
<hr />
<p style='display:none'>\(item.name)</p>
<p>
\(tags.map { "<span class=tag>\($0)</span>" }.joined(separator: " "))
<p>
</div>
</div>
</div>
"""

    }
    
    public func summarizeGroup(_ items: [MillerKit.LazyItem]) async throws -> String {
        try await ctx.engine?.build(key: FetchGPT(prompt: """
Summarize the following bullet items into one line (make sure the summary is in English and has emojis):

\(items.map { "* " + $0.name }.joined(separator: "\n"))
"""), ctx).get().response.first ?? "No summary"
    }
}

func extractImageURLs(_ text: String) -> [String] {
    let pattern = "(https?://[^\"]+\\.(png|jpg|gif))"

    do {
        // Create a regular expression object with the pattern
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        // Range for the entire string
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        // Find matches in the text
        let matches = regex.matches(in: text, options: [], range: range)
        
        // Loop through all the matches and extract the URLs
        let imageURLs = matches.map { match -> String in
            // Get the URL string from the match
            let urlRange = match.range(at: 1)  // Capture group 1 (the whole URL)
            let url = (text as NSString).substring(with: urlRange)
            return url
        }
        
        var res: [String] = []
        // Print out the extracted image URLs
        for url in imageURLs {
            res.append(url)
        }
        return res
    } catch {
        return []
    }
}
