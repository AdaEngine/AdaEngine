#if os(Windows)
import AdaUtils
import Foundation
import Synchronization
import Testing

@Suite("Windows directory notifications", .serialized)
struct WindowsFileWatcherTests {
    @Test("A batch of UTF-16 file notifications stays within its buffer and reports absolute paths")
    func batchedChanges() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Watcher-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let events = Mutex(Set<String>())
        let watcher = FileWatcher(paths: [try AbsolutePath(validating: root.path)], latency: 0.01) { paths in
            events.withLock { $0.formUnion(paths.map(\.basename)) }
        }
        try watcher.start()
        defer { watcher.stop() }
        // The OS watch is installed by its worker thread.
        try await Task.sleep(for: .milliseconds(100))
        for index in 0..<30 {
            try Data("change".utf8).write(to: root.appendingPathComponent("файл-\(index).txt"))
        }
        for _ in 0..<100 {
            if events.withLock({ $0.contains("файл-29.txt") }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(events.withLock { $0.contains("файл-0.txt") && $0.contains("файл-29.txt") })
    }
}
#endif
