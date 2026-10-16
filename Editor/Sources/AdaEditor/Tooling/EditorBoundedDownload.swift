#if canImport(FoundationNetworking)
import Foundation
import FoundationNetworking
import Synchronization

/// Streams FoundationNetworking responses to private temporary files with
/// explicit size, redirect and cancellation handling.
enum EditorBoundedDownload {
    static func receive(
        _ request: URLRequest,
        session: URLSession,
        maximumBytes: Int64,
        allowsRedirects: Bool
    ) async throws -> (URL, URLResponse) {
        let transfer = try Transfer(maximumBytes: maximumBytes, allowsRedirects: allowsRedirects)
        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                transfer.start(request, configuration: session.configuration, continuation: continuation)
            }
        } onCancel: {
            transfer.finish(.failure(CancellationError()))
        }
        if Task.isCancelled {
            try? FileManager.default.removeItem(at: result.0)
            throw CancellationError()
        }
        return result
    }

    private final class Transfer: NSObject, URLSessionDataDelegate, Sendable {
        private struct State {
            var continuation: CheckedContinuation<(URL, URLResponse), Error>?
            var result: Result<(URL, URLResponse), Error>?
            var session: URLSession?
            var task: URLSessionDataTask?
            var handle: FileHandle?
            var response: URLResponse?
            var count: Int64 = 0
        }
        private let state: Mutex<State>
        private let file: URL
        private let maximumBytes: Int64
        private let allowsRedirects: Bool

        init(maximumBytes: Int64, allowsRedirects: Bool) throws {
            self.maximumBytes = maximumBytes
            self.allowsRedirects = allowsRedirects
            file = FileManager.default.temporaryDirectory.appendingPathComponent("ada-http-" + UUID().uuidString)
            guard FileManager.default.createFile(atPath: file.path, contents: nil) else {
                throw EditorWebToolError("Could not create a temporary download.")
            }
            do { state = Mutex(State(handle: try FileHandle(forWritingTo: file))) }
            catch { try? FileManager.default.removeItem(at: file); throw error }
        }

        func start(
            _ request: URLRequest,
            configuration: URLSessionConfiguration,
            continuation: CheckedContinuation<(URL, URLResponse), Error>
        ) {
            let task = state.withLock { storage -> URLSessionDataTask? in
                if let result = storage.result {
                    continuation.resume(with: result)
                    return nil
                }
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                let task = session.dataTask(with: request)
                storage.continuation = continuation
                storage.session = session
                storage.task = task
                return task
            }
            task?.resume()
        }

        func finish(_ result: Result<(URL, URLResponse), Error>) {
            let resources = state.withLock { storage -> (CheckedContinuation<(URL, URLResponse), Error>?, URLSession?, FileHandle?)? in
                guard storage.result == nil else { return nil }
                storage.result = result
                let resources = (storage.continuation, storage.session, storage.handle)
                storage.continuation = nil
                storage.session = nil
                storage.task = nil
                storage.handle = nil
                return resources
            }
            guard let resources else { return }
            resources.1?.invalidateAndCancel()
            do { try resources.2?.close() }
            catch {
                try? FileManager.default.removeItem(at: file)
                resources.0?.resume(throwing: error)
                return
            }
            if case .failure = result { try? FileManager.default.removeItem(at: file) }
            resources.0?.resume(with: result)
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
        ) {
            guard response.expectedContentLength <= maximumBytes else {
                completionHandler(.cancel)
                finish(.failure(EditorWebToolError("Response exceeds the \(maximumBytes)-byte limit.")))
                return
            }
            state.withLock { $0.response = response }
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            let error = state.withLock { storage -> Error? in
                guard storage.result == nil else { return nil }
                guard Int64(data.count) <= maximumBytes - storage.count else {
                    return EditorWebToolError("Response exceeds the \(maximumBytes)-byte limit.")
                }
                do {
                    try storage.handle?.write(contentsOf: data)
                    storage.count += Int64(data.count)
                    return nil
                } catch { return error }
            }
            if let error { finish(.failure(error)) }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error { finish(.failure(error)); return }
            guard let response = state.withLock({ $0.response }) else {
                finish(.failure(URLError(.badServerResponse)))
                return
            }
            finish(.success((file, response)))
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(allowsRedirects ? request : nil)
        }
    }
}
#endif
