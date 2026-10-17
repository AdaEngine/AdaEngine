#if os(Linux) && !os(Android)
    import Dispatch
    import Foundation
    import Synchronization
    #if canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    public protocol InotifyDelegate: AnyObject, Sendable {
        func pathsDidReceiveEvent(_ paths: [AbsolutePath])
    }

    /// Nonblocking Linux file watching. State is locked; descriptor cleanup runs after the read source is cancelled.
    public final class Inotify: Sendable {
        public enum Error: Swift.Error {
            case invalidFD
            case failedToWatch(AbsolutePath)
        }

        public struct WatchOptions: OptionSet, Sendable {
            public let rawValue: Int32
            public init(rawValue: Int32) { self.rawValue = rawValue }
            public static let create = Self(rawValue: IN_CREATE)
            public static let delete = Self(rawValue: IN_DELETE)
            public static let deleteSelf = Self(rawValue: IN_DELETE_SELF)
            public static let move = Self(rawValue: IN_MOVE)
            public static let moveSelf = Self(rawValue: IN_MOVE_SELF)
            public static let modify = Self(rawValue: IN_MODIFY)
            public static let open = Self(rawValue: IN_OPEN)
            public static let attrib = Self(rawValue: IN_ATTRIB)
            public static let closeWrite = Self(rawValue: IN_CLOSE_WRITE)
            public static let closeNoWrite = Self(rawValue: IN_CLOSE_NOWRITE)
            public static let access = Self(rawValue: IN_ACCESS)
            public static let defaultFileWatchOptions: Self = [.deleteSelf, .moveSelf, .modify]
            public static let defaultDirectoryWatchOptions: Self = [.create, .delete, .deleteSelf, .move, .moveSelf, .modify, .closeWrite]
            public static let all: [Self] = [.create, .delete, .deleteSelf, .move, .moveSelf, .modify, .open, .attrib, .closeWrite, .closeNoWrite, .access]
        }

        public let paths: [AbsolutePath: WatchOptions]
        public let settle: Double
        private let queue = DispatchQueue(label: "org.adaengine.inotify")
        private struct State {
            weak var delegate: (any InotifyDelegate)?
            var source: (any DispatchSourceRead)?
            var watched: [Int32: AbsolutePath] = [:]
            var pending: Set<AbsolutePath> = []
            var report: DispatchWorkItem?
        }
        private let state: Mutex<State>

        public init(paths: [AbsolutePath: WatchOptions], latency: Double, delegate: (any InotifyDelegate)? = nil) {
            self.paths = paths
            settle = max(latency, 0)
            state = Mutex(State(delegate: delegate))
        }

        deinit { stop() }

        public func start() throws {
            try state.withLock { state in
                guard state.source == nil else {
                    return
                }
                let fd = inotify_init1(Int32(IN_NONBLOCK | IN_CLOEXEC))
                guard fd >= 0 else {
                    throw Error.invalidFD
                }
                var watched: [Int32: AbsolutePath] = [:]
                do {
                    for (path, options) in paths {
                        try add(path, options: options, fd: fd, watched: &watched)
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: path.pathString, isDirectory: &isDirectory), isDirectory.boolValue,
                            let entries = FileManager.default.enumerator(atPath: path.pathString) {
                            for case let entry as String in entries {
                                let child = path.appending(RelativePath(entry))
                                if FileManager.default.fileExists(atPath: child.pathString, isDirectory: &isDirectory), isDirectory.boolValue {
                                    try add(child, options: options, fd: fd, watched: &watched)
                                }
                            }
                        }
                    }
                } catch {
                    unsafe close(fd)
                    throw error
                }
                let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
                source.setEventHandler { [weak self] in self?.readEvents(fd: fd) }
                source.setCancelHandler { unsafe close(fd) }
                state.watched = watched
                state.source = source
                source.resume()
            }
        }

        public func stop() {
            state.withLock { state in
                state.source?.cancel()
                state.source = nil
                state.report?.cancel()
                state.report = nil
                state.pending.removeAll()
                state.watched.removeAll()
            }
        }

        private func add(_ path: AbsolutePath, options: WatchOptions, fd: Int32, watched: inout [Int32: AbsolutePath]) throws {
            let wd = unsafe inotify_add_watch(fd, path.pathString, UInt32(options.rawValue))
            guard wd >= 0 else {
                throw Error.failedToWatch(path)
            }
            watched[wd] = path
        }

        private func readEvents(fd: Int32) {
            var bytes = [UInt8](repeating: 0, count: 65536)
            let count = unsafe read(fd, &bytes, bytes.count)
            guard count > 0 else {
                return
            }
            state.withLock { state in
                guard state.source?.handle == UInt(fd) else {
                    return
                }
                var offset = 0
                let headerSize = MemoryLayout<inotify_event>.size
                while offset + headerSize <= count {
                    let event = unsafe bytes.withUnsafeBytes { unsafe $0.loadUnaligned(fromByteOffset: offset, as: inotify_event.self) }
                    let end = offset + headerSize + Int(event.len)
                    guard end <= count else {
                        break
                    }
                    if let root = state.watched[event.wd] {
                        let nameBytes = bytes[(offset + headerSize)..<end].prefix { $0 != 0 }
                        let name = String(bytes: nameBytes, encoding: .utf8)
                        let path = name.flatMap { $0.isEmpty ? nil : root.appending(component: $0) } ?? root
                        state.pending.insert(path)
                        if event.mask & UInt32(IN_ISDIR) != 0, event.mask & UInt32(IN_CREATE | IN_MOVED_TO) != 0 {
                            try? add(path, options: .defaultDirectoryWatchOptions, fd: fd, watched: &state.watched)
                        }
                        if event.mask & UInt32(IN_IGNORED) != 0 { state.watched[event.wd] = nil }
                    } else if event.mask & UInt32(IN_Q_OVERFLOW) != 0 {
                        state.pending.formUnion(paths.keys)
                    }
                    offset = end
                }
                state.report?.cancel()
                let report = DispatchWorkItem { [weak self] in self?.reportEvents() }
                state.report = report
                queue.asyncAfter(deadline: .now() + settle, execute: report)
            }
        }

        private func reportEvents() {
            let delivery = state.withLock { state -> ((any InotifyDelegate)?, [AbsolutePath]) in
                let events = Array(state.pending)
                state.pending.removeAll()
                return (state.delegate, events)
            }
            if !delivery.1.isEmpty { delivery.0?.pathsDidReceiveEvent(delivery.1) }
        }
    }
#endif
