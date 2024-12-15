import Collections
import Markdown
import MillerKit
import Foundation
import AsyncAlgorithms
import SwiftUI
import MillerKitExtras

public class MarkdownTreeNode {
    public let name: String
    public let markup: any Markup
    public var children: [MarkdownTreeNode]

    public init(
        name: String,
        markup: any Markup,
        children: [MarkdownTreeNode] = []
    ) {
        self.name = name
        self.children = children
        self.markup = markup
    }
    
    public func addChild(_ child: MarkdownTreeNode) {
        children.append(child)
    }
}

extension MarkdownTreeNode {
    func toLazyItem() -> LazyItem {
        let title: String
        if let _ = self.markup as? Heading {
            title = name
        } else {
            title = ""
        }

        let doc: Attribute?
        
        if let heading = self.markup as? Heading {
            doc = nil
        } else if let paragraph = self.markup as? Paragraph {
            doc = Attribute.documentation(paragraph.plainText)
        } else {
            doc = Attribute.documentation(self.markup.format())
        }

        return LazyItem.init(title, urn: "\(markup.indexInParent)", subItems: { ctx in
            AsyncStream { cont in
                Task {
                    for child in self.children {
                        cont.yield(child.toLazyItem())
                    }
                    cont.finish()
                }
            }
        }, attributes: { ctx in
            AsyncStream { cont in
                Task {
                    if let doc {
                        cont.yield(doc)
                    }
                    cont.finish()
                }
            }
        }, staticAttributes: [.prompt("Summarize this into emojis")] + (doc.map { [$0] } ?? []))
    }
}

func markdownToLazyItemWithOffset(path: String) -> AsyncStream<(Int, LazyItem)> {
    if let str = try? String(
        contentsOf: URL(fileURLWithPath: path),
        encoding: .utf8
    ) {
        return chainStreams(inputStream: markdownToLazyItemWithOffset(markdown: str), pureTransform: { ($0.0, $0.1.withURN("\(path)#\($0.0)")) })
    } else {
        return singletonStream((0, LazyItem("Unable to read \(path)")))
    }
}

func markdownToLazyItemWithOffset(markdown: String) -> AsyncStream<(Int, LazyItem)> {
    let document = Document(parsing: markdown)
    
    let pairs: [(name: String, markup: any Markup, level: Int)] = document.children.map { child in
        if let heading = child as? Heading {
            return [(name: heading.plainText, markup: child, level: heading.level)]
        } else if let ol = child as? OrderedList {
            return ol.children.map { child in
                (name: child.format(), markup: child, level: 999)
            }
        } else if let ul = child as? UnorderedList {
            return ul.children.map { child in
                (name: child.format(), markup: child, level: 999)
            }
        } else {
            return [(name: child.format(), markup: child, level: 999)]
        }
    }.flatMap { $0 }
    
    return AsyncStream { cont in
        for (index, item) in buildTree(from: pairs).enumerated() {
            cont.yield((index, item.toLazyItem()))
        }
        cont.finish()
    }
}

func buildTree(from pairs: [(name: String, markup: any Markup, level: Int)]) -> [MarkdownTreeNode] {
    var stack: [(level: Int, markup: any Markup, node: MarkdownTreeNode)] = []
    var roots: [MarkdownTreeNode] = []
    
    for pair in pairs {
        let node = MarkdownTreeNode(name: pair.name, markup: pair.markup, children: [])
        
        if stack.isEmpty || pair.level <= 1 {
            // This is a root node
            roots.append(node)
            stack = [(pair.level, pair.markup, node)]
        } else {
            // Pop nodes from the stack until we find the correct parent
            while let last = stack.last, last.level >= pair.level {
                stack.removeLast()
            }
            
            // Add the current node as a child of the parent
            if let parent = stack.last?.node {
                parent.addChild(node)
            }
            
            // Push the current node onto the stack
            stack.append((pair.level, pair.markup, node))
        }
    }

    return roots
}

struct BlogEntry: Codable {
    let path: String
    let cover: String?
}

public func MarkdownToLazyItem() -> AsyncStream<LazyItem> {
//    let paths = (try? String(contentsOf: URL(fileURLWithPath: "\(NSHomeDirectory())/docuverse.txt")).components(separatedBy: "\n").filter { !$0.hasPrefix("#") }.map {
//        NSString(string: $0).expandingTildeInPath
//    }) ?? []

    let jsonString = try? String(contentsOf: URL(fileURLWithPath: "\(NSHomeDirectory())/docuverse.json"))
    let jsonData = Data((jsonString ?? "").utf8)
    let decoder = JSONDecoder()
    let manifest = try! decoder.decode(OrderedDictionary<String, [BlogEntry]>.self, from: jsonData)

    var categories: [String: String] = [:]
    var covers: [String: String] = [:]
    var paths: [String] = []

    for (category, blogPosts) in manifest {
        for blogPost in blogPosts {
            let expandedPath = NSString(string: blogPost.path).expandingTildeInPath

            categories[expandedPath] = category
            paths.append(expandedPath)

            if let cover = blogPost.cover {
                covers[expandedPath] = cover
            }
        }
    }

    let fileWatcher = FileWatcher()
    let go = bang(fileWatcher.watchFiles(paths: paths), initialValue: ("", ""))
    let stream2 = chainStreams(inputStream: go, pureTransform: { (path, change) in
        return LazyItem("Outline", subItems: { ctx in
            AsyncStream { cont in
                Task {
                    for path in paths {
                        cont.yield(LazyItem(path, urn: path, subItems: { ctx in
                            AsyncStream { cont2 in
                                Task {
                                    for await item in markdownToLazyItemWithOffset(path: path) {
                                        cont2.yield(item.1)
                                    }
                                    cont2.finish()
                                }
                            }
                        }, staticAttributes: [
                            .init(name: "category", value: .stringValue(categories[path] ?? "unknown"))
                        ] + (covers[path].map { [Attribute(name: "cover", value: .stringValue($0))] } ?? [])))
                    }
                    cont.finish()
                }
            }
        })
    })
    
    return stream2
}

func bang<I>(_ stream: AsyncStream<I>, initialValue: I) -> AsyncStream<I> {
    AsyncStream { cont in
        Task {
            cont.yield(initialValue)
            for await val in stream {
                cont.yield(val)
            }
            cont.finish()
        }
    }
}
