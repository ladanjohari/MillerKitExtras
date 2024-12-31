import GoogleGenerativeAI
import Foundation
import MillerKit
import llbuild2fx
import TSCUtility
import TSFFutures
import TSCBasic
import TSFCAS
import llbuild2
import MillerKitExtras
import MillerKitGemini


enum APIError: Error {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case requestFailed
}


public struct Attachment: Codable, Hashable {
    let id: String
    let fileName: String
    let url: String

    public init(id: String, fileName: String, url: String) {
        self.id = id
        self.fileName = fileName
        self.url = url
    }
}

public struct Post: Codable, Hashable {
    public let id: String
    public let createdAt: String
    public let updatedAt: String
    public let body: String
    public let createdBy: String
    public let comments: [String]
    public let attachments: [String]?
    public let category: String?
    public let cover: String?
        // Include other relevant fields as needed
    
    public init(
        id: String,
        createdAt: String,
        updatedAt: String,
        body: String,
        createdBy: String,
        comments: [String],
        attachments: [String],
        category: String,
        cover: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
        self.createdBy = createdBy
        self.comments = comments
        self.attachments = attachments
        self.category = category
        self.cover = cover
    }

    public func fetchMetadataFromGPT(timeline: Timeline, ctx: Context) async throws  -> [GPTOutput]? {
        let promptForTitle = """
Here is a blog post (more like a wiki page). Suggest a
*`title`
* `slug`
* `tags`
* `summary` (A multiline string in Markdown containing short text and key points as bullet items)
* `categories`
* `imageURLs`: [String]             A list of valid image URLs from Wikipedia and Wikipedia Commons that matchi the summary
* `relatedWikipediaPages`: [String]     (a list of string URLs)
* `quality`: Int    A floating number from 0 to 1000 describing its `quality` (polish, articulation, depth of the writing). If the content is in draft mode, give it a below 500 score.
* `pinned`: Bool    If I had 500 blog posts and wanted to pick 3-5 starred posts, would you pick this blog post in this exact shape and form?
* `chi`: String     Pretend you are a revewier for CHI conference. Provide a review and critique of this submission and rate it based on strongly against to strongly pro. Make sure to provide suggestions to improve the work.

Give that in JSON format. (Use emojis but not in slugs. Keep it sharp but light).
Make sure values in JSON are properly escaped. 

Make sure tags are in slug format. Ensure the output can be parsed using an off-the-shelf JSON parser AS IS. Do not include extra markdown in there. Pure JSON. DO NOT include triple backticks in the answer.

```blog-post
\(self.body)

\(self.comments.map { timeline.findComment(id: $0) }.compactMap { $0?.body }.joined(separator: "\n\n"))
```
"""
        let ai = try await ctx.engine?.build(key: FetchGPT(prompt: promptForTitle), ctx).get().response
        let decoder = JSONDecoder()
        return try ai?.map { response in
            let a = if response.spm_chomp().starts(with: "```json") {
                response.spm_chomp().components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
            } else {
                response
            }
            do {
                return try decoder.decode(GPTOutput.self, from: a.data(using: .utf8)!)
            } catch {
                return GPTOutput(
                    title: "Unable to decode \(response)",
                    slug: nil,
                    tags: nil,
                    summary: nil,
                    categories: nil,
                    quality: nil,
                    imageURLs: nil,
                    relatedWikipediaPages: nil,
                    pinned: nil,
                    chi: nil
                )
            }
        }
    }
    
    public func toLazyItem(timeline: Timeline, ctx: Context) async throws -> LazyItem {
        let ai: [GPTOutput]?
        do {
            ai = try await self.fetchMetadataFromGPT(timeline: timeline, ctx: ctx)
        } catch {
            return LazyItem("Unable to fetch GPT data for \(self.body)")
        }

        let unixTimestamp = Double(createdAt.trimmingCharacters(in: .whitespacesAndNewlines))
        var staticAttrs: [Attribute] = []

        if let unixTimestamp {
            let date = Date(timeIntervalSince1970: Double(unixTimestamp/1000))
            staticAttrs.append(Attribute(name: "createdAt", value: .dateValue(date)))
        }

        if let ai, let firstResponse = ai.first {
            let json = try JSONEncoder().encode(firstResponse)
            staticAttrs.append(Attribute(name: "GPT", value: .jsonValue(String(data: json, encoding: .utf8)!)))
        }

        if let cat = self.category {
            staticAttrs.append(.init(name: "category", value: .stringValue(cat)))
        }

        if let cover = self.cover {
            staticAttrs.append(.init(name: "cover", value: .stringValue(cover)))
        }

        return LazyItem(
            body,
            urn: id,
            subItems: { ctx in
                let fakeComments = (self.attachments ?? []).map { attachmentID in
                    timeline.attachments.first(where: { attachment in attachment.id == attachmentID })?.url}.compactMap { $0 }.map {
                        $0
                    }
                
                return (fakeComments + comments).map { comment in
                    timeline.findComment(id: comment)
                }.compactMap { $0 }.map { comment in
                    return LazyItem(comment.body, urn: comment.id, subItems: { ctx in
                        
                        let promptSpanish = """
    Format your response in valid Markdown syntax. Liberally use headings. Machine will extrct an outline of it.
    In particular, go very deep with the structure of the candidate's response.
    Prefer use headings instead of bullet items. But include some non-heading text too. 
    
    Use this qupted text as context to teach me basic Spanish. I'm a beginner but I can read some of the alphabet. My primary language is English and Farsi.
    
    Make sure to unpack it for me and keep it fun. Use emojis as yet another layer that I can connect to. Feel free to mix Farsi, Spanish and English so I can remember better. Toss in some etymology to help me find the rhizome between natural languages.
    
    Quoted text
    
    ```
    \(comment.body)
    ```
    
    """
                        
                        let promptFarsiKamBalad = """
Format your response in valid Markdown syntax. Liberally use headings. Machine will extrct an outline of it.
In particular, go very deep with the structure of the candidate's response.
Prefer use headings instead of bullet items. But include some non-heading text too. 

Use this qupted text as context to teach me basic Farsi. I'm a beginner but I can read some of the alphabet. My primary language is English.

Make sure to unpack it for me and keep it fun. Use emojis as yet another layer that I can connect to. Feel free to mix Farsi and English so I can remember better.

Qupted text

```
\(comment.body)
```

"""
                        let promptToki = """
Format your response in valid Markdown syntax. Liberally use headings. Machine will extrct an outline of it.
In particular, go very deep with the structure of the candidate's response.
Prefer use headings instead of bullet items. But include some non-heading text too. 

Use this item extracted from my todo list to teach me toki pona. I'm a beginner.

Make sure to unpack it for me and keep it fun. Use emojis as yet another layer that I can connect to. Feel free to mix Farsi and English so I can remember better.

```
\(comment.body)
```
"""
                        let prompt0 = """
Format your response in valid Markdown syntax. Liberally use headings. Machine will extrct an outline of it.
In particular, go very deep with the structure of the candidate's response.
Prefer use headings instead of bullet items. But include some non-heading text too. 

Think clearly about the following paragraph. Follow the philosohpy that AI should challenge, not obey. Guide the reader via smart questions to think clearly:

```
\(comment.body)
```
"""
                        
                        let prompt1 = """
Give interview question prompts that would test out the expertise of a candidate on the given problem.
Also provide creative response that top candidates provide to a question like this.

Format your response in Markdown. Liberally use headings. Machine will extrct an outline of it.
In particular, go very deep with the structure of the candidate's response.
Prefer use headings instead of bullet items. But include some non-heading text too. 

Follow the philosohpy that AI should challenge, not obey. Guide the reader via smart questions to think clearly.
The problem:

```
\(comment.body)
```
"""
                        return AsyncStream { cont in
                            Task {
                                do {
                                    if let engine = ctx.engine {
                                        for response in try await engine.build(key: FetchGPT(prompt: promptSpanish), ctx).get().response {
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
                    }, alternativeSubItems: fetchFromGPT(ctx: ctx))
                }.toAsyncStream()
            },
            attributes: { ctx in
                return AsyncStream { cont in
                    Task {
                        var doc = ""
                        if let unixTimestamp {
                            let hoursAgo = Date(timeIntervalSince1970: Double(unixTimestamp/1000)).timeAgoDisplay()
                            doc += hoursAgo
                            cont.yield(.documentation(hoursAgo))
                        }
                        
                        let extraDocumentation = (ai?.map { "\($0)" } ?? ["No augmentation"]).joined(separator: "\n")
                        
                        cont.yield(.documentation([doc, extraDocumentation].joined(separator: "\n")))
                        
                        if let tags = ai?.map({ $0.tags ?? [] }).flatMap({ $0 }) {
                            cont.yield(Attribute(name: "tags", value: .listValue(tags.map { .stringValue($0) })))
                        } else {
                            cont.yield(Attribute(name: "tags", value: .listValue([])))
                        }
                        cont.finish()
                    }
                }
            },
            staticAttributes: staticAttrs,
            alternativeSubItems: fetchFromGPT(ctx: ctx)
        )
    }
}

public struct Comment: Codable {
    public let id: String
    public let seqNumber: Int
    public let body: String
    public let createdBy: String

    public init(id: String, seqNumber: Int, body: String, createdBy: String) {
        self.id = id
        self.seqNumber = seqNumber
        self.body = body
        self.createdBy = createdBy
    }
}

public struct User: Codable {
    let id: String
    let username: String
    let screenName: String
    // Include other relevant fields as needed
}

public struct PostTimeline: Codable {
    let posts: Post
    let comments: [Comment]
    let attachments: [Attachment]

    public func toLazyItem(ctx: Context) async throws -> LazyItem {
        try await self.posts.toLazyItem(timeline: Timeline(posts: [posts], comments: comments, attachments: attachments), ctx: ctx)
    }
}

public struct Timeline: Codable {
    public let posts: [Post]
    let comments: [Comment]
    let attachments: [Attachment]

    public init(posts: [Post], comments: [Comment], attachments: [Attachment]) {
        self.posts = posts
        self.comments = comments
        self.attachments = attachments
    }

    public func findComment(id: String) -> Comment? {
        comments.first(where: { $0.id == id })
    }

//    func toLazyItem(ctx: Context) async throws -> LazyItem {
//        LazyItem("FreeFeed", subItems: { ctx in
//            AsyncStream { cont in
//                Task {
//                    try await posts.parallelMap { post in
//                        try await post.toLazyItem(timeline: self, ctx: ctx)
//                    }.toAsyncStream()
//                }
//            }
//        })
//    }
}

struct KeyKey { }

public extension Context {
    var freefeedKey: String? {
        get {
            guard let key = self[ObjectIdentifier(KeyKey.self)] as? String else {
                return nil
            }
            return key
        }
        set {
            self[ObjectIdentifier(KeyKey.self)] = newValue
        }
    }
}




public class FreeFeedAPI {
    private let baseURL = "https://freefeed.net/v2"

    let ctx: Context

    public init(ctx: Context) {
        self.ctx = ctx
    }

    public func fetchUserTimeline(username: String, offset: Int) async throws -> Timeline {
        guard let url = URL(string: "\(baseURL)/timelines/\(username)?offset=\(offset)&maxComments=all") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // If authentication is required, add the token to the headers
        request.addValue(ctx.freefeedKey!, forHTTPHeaderField: "X-Authentication-Token")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        
        do {
            let timeline = try JSONDecoder().decode(Timeline.self, from: data)
            return timeline
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    public func fetchPost(postID: String, updatedAt: String) async throws -> PostTimeline {
        guard let url = URL(string: "\(baseURL)/posts/\(postID)?maxComments=all&updatedAt=\(updatedAt)") else {
            throw APIError.invalidURL
        }

        let data = try await ctx.engine!.build(key: FetchHTTP(url: url), ctx).get().data
        print(data)
        do {
            let post = try JSONDecoder().decode(PostTimeline.self, from: data)
            return post
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    func fetchUser(username: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/\(username)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // If authentication is required, include the token in the headers
        // request.addValue("yourFreefeedAPIToken", forHTTPHeaderField: "x-authentication-token")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.noData
        }

        do {
            return try JSONDecoder().decode(User.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}



func fetchUser(username: String, completion: @escaping (Result<User, Error>) -> Void) {
    let urlString = "https://freefeed.net/v1/users/\(username)"
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    // If authentication is required, add the token to the headers
    request.addValue("FRIENDFEED_API_KEY", forHTTPHeaderField: "x-authentication-token")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }

        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            completion(.success(user))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}
