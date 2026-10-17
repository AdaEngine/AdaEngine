#if os(Linux) && !os(Android)
    import AdaUtils
    import Foundation
    import Synchronization
    import Testing

    @Suite("Linux runtime")
    struct LinuxRuntimeTests {
        @Test func clockMeasuresSeconds() async throws {
            let clock = ContinuousClock()
            let start = clock.now
            let engineStart = Time.absolute
            try await Task.sleep(for: .milliseconds(30))
            let elapsed = start.duration(to: clock.now).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            #expect(abs((Time.absolute - engineStart) - seconds) < 0.01)
        }

        @Test func watchesNestedFilesAndStopsTwice() async throws {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let nested = root.appendingPathComponent("nested/deeper")
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let received = Mutex<Set<String>>([])
            let watcher = FSWatch(paths: [AbsolutePath(root.path)], latency: 0.01) { paths in
                received.withLock { $0.formUnion(paths.map(\.pathString)) }
            }
            try watcher.start()
            defer {
                watcher.stop()
                watcher.stop()
            }
            let file = nested.appendingPathComponent("hello.txt")
            try Data("Linux".utf8).write(to: file)
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(3))
            while !received.withLock({ $0.contains(file.path) }), clock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(received.withLock { $0.contains(file.path) })
        }

        @Test func missingWatchPathThrows() {
            let watcher = FSWatch(paths: [AbsolutePath("/adaengine-missing-\(UUID().uuidString)")]) { _ in }
            #expect(throws: Inotify.Error.self) { try watcher.start() }
        }
    }
#endif
