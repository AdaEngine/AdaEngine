#if canImport(FoundationNetworking)
import Foundation
import FoundationNetworking
import Synchronization

/// FoundationNetworking has no AsyncBytes. Delegate callbacks retain streaming
/// size limits; the mutex also synchronizes cancellation from the calling task.
final class EditorBoundedHTTPTransfer: NSObject, URLSessionDataDelegate, Sendable {
    private struct State: Sendable {
        var continuation: CheckedContinuation<(Data, URLResponse), any Error>?
        var session: URLSession?
        var task: URLSessionDataTask?
        var response: URLResponse?
        var data = Data()
        var receivedBytes = 0
        var cancelled = false
        var failure: (any Error)?
    }

    private let state = Mutex(State())
    private let maximumBytes: Int
    private let followRedirects: Bool
    private let output: FileHandle?

    private init(maximumBytes: Int, followRedirects: Bool, output: FileHandle?) {
        self.maximumBytes = maximumBytes
        self.followRedirects = followRedirects
        self.output = output
    }

    static func load(
        _ request: URLRequest,
        configuration: URLSessionConfiguration,
        maximumBytes: Int,
        followRedirects: Bool = true,
        output: FileHandle? = nil
    ) async throws -> (Data, URLResponse) {
        let transfer = EditorBoundedHTTPTransfer(maximumBytes: maximumBytes, followRedirects: followRedirects, output: output)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let session = URLSession(configuration: configuration, delegate: transfer, delegateQueue: nil)
                let task = session.dataTask(with: request)
                let cancelled = transfer.state.withLock { state in
                    guard !state.cancelled else { return true }
                    state.continuation = continuation
                    state.session = session
                    state.task = task
                    return false
                }
                if cancelled {
                    session.invalidateAndCancel()
                    continuation.resume(throwing: CancellationError())
                } else {
                    task.resume()
                }
            }
        } onCancel: {
            transfer.cancel()
        }
    }

    private func cancel() {
        let task = state.withLock { state in
            state.cancelled = true
            return state.task
        }
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let allowed = state.withLock { state in
            state.response = response
            guard response.expectedContentLength <= Int64(maximumBytes) else {
                state.failure = EditorWebToolError("Response exceeds the \(maximumBytes)-byte limit.")
                return false
            }
            return !state.cancelled
        }
        completionHandler(allowed ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let failed = state.withLock { state in
            guard state.failure == nil, !state.cancelled else { return true }
            guard data.count <= maximumBytes - state.receivedBytes else {
                state.failure = EditorWebToolError("Response exceeds the \(maximumBytes)-byte limit.")
                return true
            }
            do {
                if let output { try output.write(contentsOf: data) } else { state.data.append(data) }
                state.receivedBytes += data.count
                return false
            } catch {
                state.failure = error
                return true
            }
        }
        if failed { dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let completion = state.withLock { state -> (CheckedContinuation<(Data, URLResponse), any Error>?, Result<(Data, URLResponse), any Error>) in
            defer {
                state.continuation = nil
                state.session = nil
                state.task = nil
            }
            if let failure = state.failure ?? (state.cancelled ? CancellationError() : error) {
                return (state.continuation, .failure(failure))
            }
            guard let response = state.response else {
                return (state.continuation, .failure(EditorWebToolError("Missing HTTP response.")))
            }
            return (state.continuation, .success((state.data, response)))
        }
        session.finishTasksAndInvalidate()
        completion.0?.resume(with: completion.1)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(followRedirects ? request : nil)
    }
}
#endif
