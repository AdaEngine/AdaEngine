#if canImport(FoundationNetworking)
@testable import AdaEditor
import Foundation
import FoundationNetworking
import Testing

@Suite("Portable bounded HTTP downloads")
struct EditorBoundedHTTPTransferTests {
    @Test("A complete response is written exactly once")
    func downloadsBytes() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let (data, response) = try await EditorBoundedHTTPTransfer.load(
            request("small"), configuration: session.configuration, maximumBytes: 1024, followRedirects: false
        )
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == Data(repeating: 120, count: 64))
    }

    @Test("Limits apply to headers and unknown-length bodies", arguments: ["large", "chunked"])
    func rejectsOversize(path: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await EditorBoundedHTTPTransfer.load(
                request(path), configuration: session.configuration, maximumBytes: 1024, followRedirects: false
            )
            Issue.record("An oversized response was accepted")
        } catch let error as EditorWebToolError {
            #expect(error.message.contains("1024-byte limit"))
        }
    }

    @Test("Cancellation before start resolves its continuation")
    func alreadyCancelled() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await EditorBoundedHTTPTransfer.load(
                request("small"), configuration: session.configuration, maximumBytes: 1024, followRedirects: false
            )
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DownloadFixtureProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func request(_ path: String) throws -> URLRequest {
        URLRequest(url: try #require(URL(string: "https://fixture.invalid/" + path)))
    }
}

private final class DownloadFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let size = url.lastPathComponent == "small" ? 64 : 4096
        let headers = url.lastPathComponent == "chunked" ? [:] : ["Content-Length": String(size)]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 120, count: size))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
#endif
