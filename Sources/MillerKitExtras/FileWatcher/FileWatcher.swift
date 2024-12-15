import Foundation

class FileWatcher {
    private var fileDescriptors: [Int32] = []
    private var sources: [DispatchSourceFileSystemObject] = []

    func watchFiles(paths: [String]) -> AsyncStream<(String, String)> {
        AsyncStream { continuation in
            for path in paths {
                guard let fileDescriptor = openFileDescriptor(for: path) else {
                    print("Failed to open file: \(path)")
                    continue
                }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fileDescriptor,
                    eventMask: [.write, .delete, .rename],
                    queue: DispatchQueue.global()
                )

                source.setEventHandler {
                    if let event = source.data as? DispatchSource.FileSystemEvent {
                        if event.contains(.write) {
                            if let str = try? String(contentsOf: URL(filePath: path), encoding: .utf8) {
                                continuation.yield((path, str))
                            }
                        }
                        if event.contains(.delete) {
                            continuation.yield((path, "File deleted: \(path)"))
                            source.cancel()
                        }
                        if event.contains(.rename) {
                            continuation.yield((path, "File renamed: \(path)"))
                            source.cancel()
                        }
                    }
                }

                source.setCancelHandler {
                    close(fileDescriptor)
                }

                source.resume()
                sources.append(source)
            }

            // Cleanup continuation on task cancellation
            continuation.onTermination = { _ in
                self.cleanup()
            }
        }
    }

    private func openFileDescriptor(for path: String) -> Int32? {
        let fileDescriptor = open(path, O_EVTONLY)
        return fileDescriptor >= 0 ? fileDescriptor : nil
    }

    private func cleanup() {
        for source in sources {
            source.cancel()
        }
        for fd in fileDescriptors {
            close(fd)
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    deinit {
        cleanup()
    }
}
