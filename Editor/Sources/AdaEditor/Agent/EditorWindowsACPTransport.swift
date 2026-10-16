#if os(Windows)
import Dispatch
import Foundation

/// All writes and close operations share one serial queue. A full stdin pipe never
/// blocks the ACP actor, so it can keep draining stdout and processing cancellation.
actor EditorWindowsACPWriter {
    private let handle: FileHandle
    private let queue = DispatchQueue(label: "org.adaengine.acp.stdin")

    init(_ handle: FileHandle) { self.handle = handle }

    func write(_ data: Data) async throws {
        let handle = self.handle
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    try handle.write(contentsOf: data)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func close() async {
        let handle = self.handle
        await withCheckedContinuation { continuation in
            queue.async {
                try? handle.close()
                continuation.resume()
            }
        }
    }
}

enum EditorWindowsACPTransport {
    static let maximumMessageBytes = 16 * 1024 * 1024

    static func chunks(_ handle: FileHandle, onOverflow: @escaping @Sendable () -> Void = {}) -> AsyncStream<Data> {
        AsyncStream(bufferingPolicy: .bufferingOldest(256)) { continuation in
            handle.readabilityHandler = { readable in
                let data = readable.availableData
                if data.isEmpty {
                    readable.readabilityHandler = nil
                    continuation.finish()
                } else {
                    if case .dropped = continuation.yield(data) {
                        readable.readabilityHandler = nil
                        onOverflow()
                        continuation.finish()
                    }
                }
            }
            continuation.onTermination = { _ in handle.readabilityHandler = nil }
        }
    }
}
#endif
