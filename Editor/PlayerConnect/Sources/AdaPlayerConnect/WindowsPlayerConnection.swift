#if os(Windows)
import CWindowsPlayer
import Dispatch
import Foundation

public struct PlayerEndpoint: Sendable, Equatable {
    public let host: String
    public let port: UInt16
    public init(host: String, port: UInt16) { self.host = host; self.port = port }
}

/// Blocking WinSock calls run on separate serial read/write queues, leaving the
/// UI executor free. A connection has exactly one reader; writes are ordered.
@MainActor
public final class PlayerConnection {
    nonisolated public static let serviceType = "_adaplayer._tcp"
    nonisolated public static let maximumFrameBytes = 96 * 1024 * 1024
    public var onFailure: ((String) -> Void)?
    private var socket: UInt = .max
    private let endpoint: PlayerEndpoint?
    private var opening: Task<UInt, Error>?
    private var cancelled = false
    private let reads = DispatchQueue(label: "AdaPlayer.read", qos: .userInitiated)
    private let writes = DispatchQueue(label: "AdaPlayer.write", qos: .userInitiated)
    public init(endpoint: PlayerEndpoint) { self.endpoint = endpoint }
    init(socket: UInt) { self.socket = socket; endpoint = nil }

    public func start() {
        guard opening == nil, socket == .max, let endpoint, !cancelled else { return }
        opening = Task {
            let value: UInt = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let value = endpoint.host.withCString { ada_player_connect($0, endpoint.port) }
                    continuation.resume(returning: value)
                }
            }
            guard !cancelled else { ada_player_close(value); throw CancellationError() }
            guard value != .max else { throw PlayerConnectError.invalid("Cannot connect to AdaPlayer. Check the address, port and firewall.") }
            socket = value
            return value
        }
    }

    public func cancel() {
        cancelled = true
        opening?.cancel()
        if socket != .max { ada_player_close(socket); socket = .max }
    }

    public func send(_ message: PlayerMessage) async throws {
        let payload = try JSONEncoder().encode(message)
        guard payload.count <= Self.maximumFrameBytes else { throw PlayerConnectError.invalid("Message is too large.") }
        let count = UInt32(payload.count)
        var frame = Data([UInt8(count >> 24), UInt8(truncatingIfNeeded: count >> 16), UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count)])
        frame.append(payload)
        let data = frame
        let handle = try await connectedSocket()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                writes.async {
                    let result = data.withUnsafeBytes { ada_player_write(handle, $0.baseAddress, $0.count) }
                    if result != 0 { continuation.resume() }
                    else { continuation.resume(throwing: PlayerConnectError.invalid("AdaPlayer disconnected while sending.")) }
                }
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    public func receive(maximumBytes: Int = maximumFrameBytes) async throws -> PlayerMessage {
        let handle = try await connectedSocket()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                reads.async {
                    do {
                        var header = Data(count: 4)
                        guard header.withUnsafeMutableBytes({ ada_player_read(handle, $0.baseAddress, 4) }) != 0 else {
                            throw PlayerConnectError.invalid("AdaPlayer disconnected.")
                        }
                        let count = header.reduce(0) { ($0 << 8) | Int($1) }
                        guard count > 0, count <= maximumBytes, count <= Self.maximumFrameBytes else {
                            throw PlayerConnectError.invalid("Invalid message size.")
                        }
                        var payload = Data(count: count)
                        guard payload.withUnsafeMutableBytes({ ada_player_read(handle, $0.baseAddress, $0.count) }) != 0 else {
                            throw PlayerConnectError.invalid("AdaPlayer disconnected.")
                        }
                        let message = try JSONDecoder().decode(PlayerMessage.self, from: payload)
                        guard message.version == 1 else { throw PlayerConnectError.invalid("AdaPlayer protocol version mismatch. Update both apps.") }
                        continuation.resume(returning: message)
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    private func connectedSocket() async throws -> UInt {
        if let opening { _ = try await opening.value }
        try Task.checkCancellation()
        guard !cancelled, socket != .max else { throw PlayerConnectError.invalid("AdaPlayer is not connected.") }
        return socket
    }
}
#endif
