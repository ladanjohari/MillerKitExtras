import TSCUtility
import GoogleGenerativeAI

struct AIKey {}

public extension Context {
    var ai: GenerativeModel? {
        get {
            guard let ai = self[ObjectIdentifier(AIKey.self)] as? GenerativeModel else {
                return nil
            }
            return ai
        }
        set {
            self[ObjectIdentifier(AIKey.self)] = newValue
        }
    }
}

public struct GPTOutput: Codable {
    public let title: String?
    public let slug: String?
    public let tags: [String]?
    public let summary: String?
    public let categories: [String]?
    public let quality: Double?
    public let imageURLs: [String]?
    public let relatedWikipediaPages: [String]?
    public let pinned: Bool?
    public let chi: String?

    public init(
        title: String?,
        slug: String?,
        tags: [String]?,
        summary: String?,
        categories: [String]?,
        quality: Double?,
        imageURLs: [String]?,
        relatedWikipediaPages: [String]?,
        pinned: Bool?,
        chi: String?
    ) {
        self.title = title
        self.slug = slug
        self.tags = tags
        self.summary = summary
        self.categories = categories
        self.quality = quality
        self.imageURLs = imageURLs
        self.relatedWikipediaPages = relatedWikipediaPages
        self.pinned = pinned
        self.chi = chi
    }
}

