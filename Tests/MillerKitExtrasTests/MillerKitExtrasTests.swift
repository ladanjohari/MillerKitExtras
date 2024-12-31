import Testing
@testable import MillerKitExtras
import MillerKit
import Foundation
import llbuild2fx
import llbuild2
import TSCBasic
import Logging
import GoogleGenerativeAI

public func getContext() -> Context {
    let ai = GenerativeModel(name: "gemini-1.5-flash-latest", apiKey: "GEMINI_KEY")


    var ctx: Context = Context()
    ctx.ai = ai
    ctx.logger = Logger(label: "org.millerkit")
    // ctx.tracer = OSLogTracer()

    let key = "FRIENDFEED_KEY"

    ctx.freefeedKey = key
    ctx.group = .singletonMultiThreadedEventLoopGroup
    
    // let db = LLBInMemoryCASDatabase(group: group)
    let db = LLBFileBackedCASDatabase(
        group: ctx.group,
        path: AbsolutePath("\(NSHomeDirectory())/my-cas/cas")
    )

    ctx.db = db

    let functionCache = LLBFileBackedFunctionCache(group: ctx.group, path: AbsolutePath("\(NSHomeDirectory())/my-cas/function-cache"), version: "0")
    
    let executor = FXLocalExecutor()


    ctx.engine = FXBuildEngine(
        group: ctx.group,
        db: ctx.db,
        functionCache: functionCache,
        executor: executor
    )

    return ctx
}

@Test func testTableOfContentsMarkdown() async throws {
    let example = """
Some content prior to the first heading

# First chapter

Some intro content for first chapter

## A section in first chapter

## Another section in first chapter

### A subsection

# Second chapter

# References

# Acknowledgements

"""
}

@Test func testMarkdownGrafting() async throws {
    let main = """
# =GRAFT("./intro.md")

# some chapter in between

## =GRAFT("./references.md")
"""

    let intro = """
# Introduction

Give some background about the problem.

## Running example

Describe running example here.
"""

    let references = """
# References
"""

    // RenderMarkdown(["intro.md": intro, "references.md": references, "main.md": main])
}

@Test func testTableOfContentsGoogleDocs() async throws {
    
}

@Test func testJSONBrowser() async throws {
    
}

@Test func testSymbolBrowserEnumCases() async throws {
    
}

@Test func testSymbolBrowserDocs() async throws {
    
}

@Test func testLLMElaboration() async throws {
    
}


@Test func example() async throws {
//    let ctx = getContext()
//
//    let markdown = LazyItem("Markdown", subItems: { ctx in
//        MarkdownToLazyItem()
//    }, alternativeSubItems: { selectedItem, prompt in
//        singletonStream(.init("Prompt was \(prompt)"))
//    })
//
//    let flattenedMarkdown = LazyItem("markdown", subItems: { ctx in
//        AsyncStream { cont in
//            Task {
//                if let subItems = markdown.subItems {
//                    for await item in subItems(ctx) {
//                        if let subSubItems = item.subItems {
//                            for await post in subSubItems(ctx) {
//                                cont.yield(post)
//                                break
//                            }
//                        }
//                    }
//                }
//                cont.finish()
//            }
//        }
//    })
//    try await flattenedMarkdown.materializeBeautifulStaticHTMLSite(
//        ctx: ctx,
//        siteGeneratorDelegate: MyStaticSiteGenerator(ctx: ctx)
//    )
}

func traverse(path: [UInt], root: LazyItem, ctx: Context) async -> LazyItem? {
    if let head = path.first {
       if let subItems = root.subItems {
           var i = 0
           for await child in await subItems(ctx) {
               if i == head {
                   return await traverse(path: Array(path.dropFirst()), root: child, ctx: ctx)
               }
               i += 1
           }
           return nil
       } else {
           return nil
       }
    } else {
        return root
    }
}

@Test func example2() async throws {
    let item = LazyItem("My item", subItems: { ctx in
        AsyncStream { cont in
            cont.yield(LazyItem("child 1"))
            cont.yield(LazyItem("child 2"))
        }
    })
    let res = await traverse(path: [], root: item, ctx: getContext())
}
