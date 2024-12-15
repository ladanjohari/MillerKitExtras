public extension Sequence {
    func toAsyncStream() -> AsyncStream<Element> {
        AsyncStream { cont in
            Task {
                for elem in self {
                    cont.yield(elem)
                }
                cont.finish()
            }
        }
    }
}
