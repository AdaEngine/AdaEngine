//
//  FileWatcher.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/19/24.
//

// TODO: Add support for events like create, delete, modify, etc.

// Take from https://github.com/swiftlang/swift-tools-support-core/blob/main/Sources/TSCUtility/FSWatch.swift

import Foundation
import Logging

#if canImport(Dispatch)
    import Dispatch
#endif
#if os(Windows)
    import WinSDK
#endif

public typealias FileWatcher = FSWatch

/// FSWatch is a cross-platform filesystem watching utility.
public final class FSWatch: @unchecked Sendable {
    public typealias EventReceivedBlock = @Sendable (_ paths: [AbsolutePath]) -> Void

    /// Delegate for handling events from the underling watcher.
    final class _WatcherDelegate: @unchecked Sendable {
        let block: EventReceivedBlock

        init(block: @escaping EventReceivedBlock) {
            self.block = block
        }

        func pathsDidReceiveEvent(_ paths: [AbsolutePath]) {
            block(paths)
        }
    }

    private var isStarted = false
    private let watcherHandler: _WatcherDelegate

    /// The paths being watched.
    public let paths: [AbsolutePath]

    /// The underlying file watching utility.
    ///
    /// This is FSEventStream on macOS and inotify on linux.
    private var _watcher: _FileWatcher!

    /// The number of seconds the watcher should wait before passing the
    /// collected events to the clients.
    let latency: Double

    /// Create an instance with given paths.
    ///
    /// Paths can be files or directories. Directories are watched recursively.
    public init(paths: [AbsolutePath], latency: Double = 1, block: @escaping EventReceivedBlock) {
        precondition(!paths.isEmpty)
        self.paths = paths
        self.latency = latency
        let watcherDelegate = _WatcherDelegate(block: block)
        self.watcherHandler = watcherDelegate

        #if WASM || os(Android) || os(OpenBSD) || os(FreeBSD)
            self._watcher = NoOpWatcher(paths: paths, latency: latency, delegate: watcherDelegate)
        #elseif os(Windows)
            self._watcher = RDCWatcher(paths: paths, latency: latency, delegate: watcherDelegate)
        #elseif canImport(Glibc) || canImport(Musl)
            var ipaths: [AbsolutePath: Inotify.WatchOptions] = [:]

            for path in paths {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: path.pathString, isDirectory: &isDirectory), isDirectory.boolValue {
                    ipaths[path] = .defaultDirectoryWatchOptions
                } else {
                    ipaths[path] = .defaultFileWatchOptions
                }
            }

            self._watcher = Inotify(paths: ipaths, latency: latency, delegate: watcherDelegate)
        #elseif os(macOS)
            self._watcher = FSEventStream(paths: paths, latency: latency, delegate: watcherDelegate)
        #else
            fatalError("Unsupported platform")
        #endif
    }

    deinit {
        _watcher.stop()
        isStarted = false
    }

    /// Start watching the filesystem for events.
    ///
    /// This method should be called only once.
    public func start() throws {
        precondition(isStarted == false, "FSWatcher must be started only once")
        // FIXME: Write precondition to ensure its called only once.
        try _watcher.start()
        isStarted = true
    }

    /// Stop watching the filesystem.
    ///
    /// This method should be called after start() and the object should be thrown away.
    public func stop() {
        // FIXME: Write precondition to ensure its called after start() and once only.
        _watcher.stop()
    }
}

/// Protocol to which the different file watcher implementations should conform.
private protocol _FileWatcher {
    func start() throws
    func stop()
}

#if WASM || os(Android) || os(OpenBSD) || os(FreeBSD) || (!os(macOS) && canImport(Darwin))
    extension FSWatch._WatcherDelegate: NoOpWatcherDelegate {}
    extension NoOpWatcher: _FileWatcher {}
#elseif os(Windows)
    extension FSWatch._WatcherDelegate: RDCWatcherDelegate {}
    extension RDCWatcher: _FileWatcher {}
#elseif canImport(Glibc) || canImport(Musl)
    extension FSWatch._WatcherDelegate: InotifyDelegate {}
    extension Inotify: _FileWatcher {}
#elseif os(macOS)
    extension FSWatch._WatcherDelegate: FSEventStreamDelegate {}
    extension FSEventStream: _FileWatcher {}
#else
    #error("Implementation required")
#endif

// MARK: - inotify

#if WASM || os(Android) || os(FreeBSD) || os(OpenBSD) || (!os(macOS) && canImport(Darwin))

    public protocol NoOpWatcherDelegate: AnyObject {
        func pathsDidReceiveEvent(_ paths: [AbsolutePath])
    }

    public final class NoOpWatcher {
        public init(paths _: [AbsolutePath], latency _: Double, delegate _: NoOpWatcherDelegate? = nil) {
        }

        public func start() throws {}

        public func stop() {}
    }

#elseif os(Windows)

    public protocol RDCWatcherDelegate: AnyObject, Sendable {
        func pathsDidReceiveEvent(_ paths: [AbsolutePath])
    }

    /// Bindings for `ReadDirectoryChangesW` C APIs.
    public final class RDCWatcher {
        @safe
        class Watch: @unchecked Sendable {
            var hDirectory: HANDLE
            let path: String
            var overlapped: OVERLAPPED
            var terminate: HANDLE
            var buffer: UnsafeMutableBufferPointer<DWORD>  // buffer must be DWORD-aligned
            var thread: TSCBasic.Thread?

            public init(directory handle: HANDLE, _ path: String) {
                unsafe self.hDirectory = handle
                self.path = path
                unsafe self.overlapped = OVERLAPPED()
                unsafe self.overlapped.hEvent = CreateEventW(nil, false, false, nil)
                unsafe self.terminate = CreateEventW(nil, true, false, nil)

                unsafe self.buffer =
                    UnsafeMutableBufferPointer<DWORD>.allocate(capacity: 64 * 1024 / MemoryLayout<DWORD>.stride)
            }

            deinit {
                unsafe SetEvent(self.terminate)
                unsafe CloseHandle(self.terminate)
                unsafe CloseHandle(self.overlapped.hEvent)
                unsafe CloseHandle(hDirectory)
                unsafe self.buffer.deallocate()
            }
        }

        /// The paths being watched.
        private let paths: [AbsolutePath]

        /// The settle period (in seconds).
        private let settle: Double

        /// The watcher delegate.
        private weak var delegate: RDCWatcherDelegate?

        private let watches: [Watch]
        private let queue: DispatchQueue =
            DispatchQueue(label: "org.adaengine.\(RDCWatcher.self).callback")

        public init(paths: [AbsolutePath], latency: Double, delegate: RDCWatcherDelegate? = nil) {
            self.paths = paths
            self.settle = latency
            self.delegate = delegate

            self.watches = paths.map { path in
                unsafe path.pathString.withCString(encodedAs: UTF16.self) {
                    let dwDesiredAccess: DWORD = DWORD(FILE_LIST_DIRECTORY)
                    let dwShareMode: DWORD = DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
                    let dwCreationDisposition: DWORD = DWORD(OPEN_EXISTING)
                    let dwFlags: DWORD = DWORD(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED)

                    let handle: HANDLE =
                        unsafe CreateFileW(
                            $0,
                            dwDesiredAccess,
                            dwShareMode,
                            nil,
                            dwCreationDisposition,
                            dwFlags,
                            nil
                        )
                    unsafe assert(!(handle == INVALID_HANDLE_VALUE))

                    return unsafe Watch(directory: handle, path.pathString)
                }
            }
        }

        public func start() throws {
            // TODO(compnerd) can we compress the threads to a single worker thread
            self.watches.forEach { watch in
                watch.thread = TSCBasic.Thread { [delegate = self.delegate, queue = self.queue, weak watch] in
                    guard let watch else {
                        return
                    }

                    while true {
                        let dwNotifyFilter: DWORD =
                            DWORD(FILE_NOTIFY_CHANGE_FILE_NAME)
                            | DWORD(FILE_NOTIFY_CHANGE_DIR_NAME)
                            | DWORD(FILE_NOTIFY_CHANGE_SIZE)
                            | DWORD(FILE_NOTIFY_CHANGE_LAST_WRITE)
                            | DWORD(FILE_NOTIFY_CHANGE_CREATION)
                        var dwBytesReturned: DWORD = 0
                        if unsafe !ReadDirectoryChangesW(
                            watch.hDirectory,
                            watch.buffer.baseAddress,
                            DWORD(watch.buffer.count * MemoryLayout<DWORD>.stride),
                            true,
                            dwNotifyFilter,
                            &dwBytesReturned,
                            &watch.overlapped,
                            nil
                        ) {
                            return
                        }

                        var handles: (HANDLE?, HANDLE?) = unsafe (watch.terminate, watch.overlapped.hEvent)
                        switch unsafe WaitForMultipleObjects(2, &handles.0, false, INFINITE) {
                        case WAIT_OBJECT_0 + 1:
                            break
                        case DWORD(WAIT_TIMEOUT):  // Spurious Wakeup?
                            continue
                        case WAIT_FAILED, WAIT_OBJECT_0:  // Terminate Request
                            unsafe CancelIoEx(watch.hDirectory, &watch.overlapped)
                            unsafe GetOverlappedResult(watch.hDirectory, &watch.overlapped, &dwBytesReturned, true)
                            unsafe CloseHandle(watch.hDirectory)
                            unsafe watch.hDirectory = INVALID_HANDLE_VALUE
                            return
                        default:
                            unsafe CancelIoEx(watch.hDirectory, &watch.overlapped)
                            unsafe GetOverlappedResult(watch.hDirectory, &watch.overlapped, &dwBytesReturned, true)
                            unsafe CloseHandle(watch.hDirectory)
                            unsafe watch.hDirectory = INVALID_HANDLE_VALUE
                            return
                        }

                        if unsafe !GetOverlappedResult(watch.hDirectory, &watch.overlapped, &dwBytesReturned, false) {
                            queue.async {
                                delegate?.pathsDidReceiveEvent([AbsolutePath(watch.path)])
                            }
                            return
                        }

                        // There was a buffer underrun on the kernel side.  We may
                        // have lost events, please re-synchronize.
                        if dwBytesReturned == 0 {
                            queue.async { delegate?.pathsDidReceiveEvent([AbsolutePath(watch.path)]) }
                            continue
                        }

                        var paths: [AbsolutePath] = []
                        let byteCount = min(Int(dwBytesReturned), watch.buffer.count * MemoryLayout<DWORD>.stride)
                        guard let baseAddress = unsafe watch.buffer.baseAddress else { return }
                        let bytes = unsafe UnsafeRawPointer(baseAddress)
                        var offset = 0
                        // FILE_NOTIFY_INFORMATION has three DWORDs followed by a variable UTF-16 name.
                        // NextEntryOffset is a byte offset, and zero terminates the chain.
                        while offset + 12 <= byteCount {
                            let next = unsafe Int(bytes.load(fromByteOffset: offset, as: DWORD.self))
                            let length = unsafe Int(bytes.load(fromByteOffset: offset + 8, as: DWORD.self))
                            guard length % 2 == 0, length <= byteCount - offset - 12 else { break }
                            let name = unsafe bytes.advanced(by: offset + 12).assumingMemoryBound(to: WCHAR.self)
                            let file = unsafe String(utf16CodeUnits: name, count: length / 2)
                            if let relative = try? RelativePath(validating: file) {
                                paths.append(AbsolutePath(watch.path).appending(relative))
                            }
                            guard next != 0 else { break }
                            guard next % MemoryLayout<DWORD>.alignment == 0,
                                  next >= 12 + length, next <= byteCount - offset else { break }
                            offset += next
                        }

                        queue.async { [paths] in
                            delegate?.pathsDidReceiveEvent(paths)
                        }
                    }
                }
                watch.thread?.start()
            }
        }

        public func stop() {
            self.watches.forEach {
                unsafe SetEvent($0.terminate)
                $0.thread?.join()
            }
        }
    }

#endif

// MARK: - FSEventStream

#if os(macOS)

    private func callback(
        streamRef _: ConstFSEventStreamRef,
        clientCallBackInfo: UnsafeMutableRawPointer?,
        numEvents _: Int,
        eventPaths: UnsafeMutableRawPointer,
        eventFlags _: UnsafePointer<FSEventStreamEventFlags>,
        eventIds _: UnsafePointer<FSEventStreamEventId>
    ) {
        let eventStream = unsafe unsafeBitCast(clientCallBackInfo, to: FSEventStream.self)

        // We expect the paths to be reported as a CFArray because we requested CFTypes.
        let eventPaths = unsafe unsafeBitCast(eventPaths, to: CFArray.self) as? [String] ?? []

        // Compute the set of paths that were changed.
        do {
            let paths = try eventPaths.compactMap { try AbsolutePath(validating: $0) }

            eventStream.callbacksQueue.async {
                eventStream.delegate?.pathsDidReceiveEvent(paths)
            }
        } catch {
            Logger(label: "org.adaengine.utils.filewatcher").error("\(error.localizedDescription)")
        }
    }

    public protocol FSEventStreamDelegate: AnyObject {
        func pathsDidReceiveEvent(_ paths: [AbsolutePath])
    }

    /// Wrapper for Darwin's FSEventStream API.
    @safe
    public final class FSEventStream: @unchecked Sendable {
        /// The errors encountered during fs event watching.
        public enum Error: Swift.Error {
            case unknownError
        }

        /// Reference to the underlying event stream.
        ///
        private var stream: FSEventStreamRef?

        /// Reference to the handler that should be called.
        weak var delegate: FSEventStreamDelegate?

        /// Callback queue for the delegate.
        let callbacksQueue = DispatchQueue(label: "org.adaengine.\(FSEventStream.self).callback")
        private let streamQueue = DispatchQueue(label: "org.adaengine.\(FSEventStream.self).stream")

        public init(
            paths: [AbsolutePath],
            latency: Double,
            delegate: FSEventStreamDelegate,
            flags: FSEventStreamCreateFlags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) {
            self.delegate = delegate

            // Create the context that needs to be passed to the callback.
            var callbackContext = unsafe FSEventStreamContext()
            unsafe callbackContext.info = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)

            // Convert AbsolutePath array to String array for FSEventStreamCreate
            let pathStrings = paths.map(\.pathString)
            let pathsArray = pathStrings as CFArray

            // Create the stream.
            unsafe self.stream = FSEventStreamCreate(
                nil,
                callback,
                &callbackContext,

                pathsArray,

                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                latency,
                flags
            )
        }

        // Start delivery on a dispatch queue.
        public func start() throws {
            guard let stream = unsafe self.stream else {
                throw Error.unknownError
            }
            unsafe FSEventStreamSetDispatchQueue(stream, streamQueue)
            guard unsafe FSEventStreamStart(stream) else {
                unsafe FSEventStreamSetDispatchQueue(stream, nil)
                throw Error.unknownError
            }
        }

        /// Stop watching the events.
        public func stop() {
            guard let stream = unsafe self.stream else {
                return
            }
            unsafe FSEventStreamStop(stream)
            unsafe FSEventStreamSetDispatchQueue(stream, nil)
            unsafe FSEventStreamInvalidate(stream)
            unsafe FSEventStreamRelease(stream)
            unsafe self.stream = nil
        }
    }
#endif

#if !os(WASI)
    enum TSCBasic {
        /// This class bridges the gap between Darwin and Linux Foundation Threading API.
        /// It provides closure based execution and a join method to block the calling thread
        /// until the thread is finished executing.
        public final class Thread: @unchecked Sendable {
            /// The thread implementation which is Foundation.Thread on Linux and
            /// a Thread subclass which provides closure support on Darwin.
            private var thread: ThreadImpl!

            /// Condition variable to support blocking other threads using join when this thread has not finished executing.
            private var finishedCondition: Condition

            /// A boolean variable to track if this thread has finished executing its task.
            private var isFinished: Bool

            /// Creates an instance of thread class with closure to be executed when start() is called.
            public init(task: @escaping @Sendable () -> Void) {
                isFinished = false
                finishedCondition = Condition()

                // Wrap the task with condition notifying any other threads blocked due to this thread.
                // Capture self weakly to avoid reference cycle. In case Thread is deinited before the task
                // runs, skip the use of finishedCondition.
                let theTask: @Sendable () -> Void = { [weak self] in
                    if let strongSelf = self {
                        precondition(!strongSelf.isFinished)
                        strongSelf.finishedCondition.whileLocked {
                            task()
                            strongSelf.isFinished = true
                            strongSelf.finishedCondition.broadcast()
                        }
                    } else {
                        // If the containing thread has been destroyed, we can ignore the finished condition and just run the
                        // task.
                        task()
                    }
                }

                self.thread = ThreadImpl(block: theTask)
            }

            /// Starts the thread execution.
            public func start() {
                thread.start()
            }

            /// Blocks the calling thread until this thread is finished execution.
            public func join() {
                finishedCondition.whileLocked {
                    while !isFinished {
                        finishedCondition.wait()
                    }
                }
            }

            /// Causes the calling thread to yield execution to another thread.
            public static func yield() {
                #if os(Windows)
                    SwitchToThread()
                #else
                    sched_yield()
                #endif
            }
        }

        #if canImport(Darwin)
            /// A helper subclass of Foundation's Thread with closure support.
            private final class ThreadImpl: Foundation.Thread {
                /// The task to be executed.
                private let task: @Sendable () -> Void

                override func main() {
                    task()
                }

                init(block task: @escaping @Sendable () -> Void) {
                    self.task = task
                }
            }
        #else
            // Thread on Linux supports closure so just use it directly.
            typealias ThreadImpl = Foundation.Thread
        #endif

        public struct Condition: Sendable {
            private let _condition = NSCondition()

            /// Create a new condition.
            public init() {}

            /// Wait for the condition to become available.
            public func wait() {
                _condition.wait()
            }

            /// Blocks the current thread until the condition is signaled or the specified time limit is reached.
            ///
            /// - Returns: true if the condition was signaled; otherwise, false if the time limit was reached.
            public func wait(until limit: Date) -> Bool {
                return _condition.wait(until: limit)
            }

            /// Signal the availability of the condition (awake one thread waiting on
            /// the condition).
            public func signal() {
                _condition.signal()
            }

            /// Broadcast the availability of the condition (awake all threads waiting
            /// on the condition).
            public func broadcast() {
                _condition.broadcast()
            }

            /// A helper method to execute the given body while condition is locked.
            /// - Note: Will ensure condition unlocks even if `body` throws.
            public func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
                _condition.lock()
                defer { _condition.unlock() }
                return try body()
            }
        }
    }
#endif
