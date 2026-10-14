#if canImport(Network) || os(Windows)
import Foundation
#if canImport(Network)
import Network
#else
import CWindowsPlayer
#endif
import Observation

/// A foreground-only host with one paired editor. Pairing expires on disconnect.
@Observable @MainActor
public final class PlayerHost {
    public private(set) var code = String(Int.random(in: 100000...999999))
    public private(set) var status = "Starting…"
    public private(set) var port: UInt16?
    public private(set) var isPaired = false
    public var onDeploy: ((PlayerProjectSnapshot) async throws -> Void)?
    public var onStop: (() -> Void)?
    #if canImport(Network)
    @ObservationIgnored private var listener: NWListener?
    #else
    @ObservationIgnored private var listener: WindowsPlayerListener?
    #endif
    @ObservationIgnored private var connection: PlayerConnection?
    @ObservationIgnored private var session: Task<Void, Never>?
    @ObservationIgnored private var timeout: Task<Void, Never>?

    public init() {}

    public func start(name: String) throws {
        guard listener == nil else { return }
        #if canImport(Network)
        let listener = try NWListener(using: .tcp)
        self.listener = listener
        listener.service = .init(name: name, type: PlayerConnection.serviceType)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready: self.port = listener.port?.rawValue; self.status = "Waiting for AdaEditor"
                case .failed(let error): self.status = error.localizedDescription; self.shutdown()
                default: break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] incoming in
            Task { @MainActor in self?.accept(incoming) }
        }
        listener.start(queue: .main)
        #else
        let listener = try WindowsPlayerListener { [weak self] in self?.accept($0) }
        self.listener = listener
        port = listener.port
        status = "Waiting for Ada Studio · \(ProcessInfo.processInfo.hostName):\(listener.port)"
        #endif
    }

    public func shutdown() {
        listener?.cancel()
        listener = nil
        disconnect()
        port = nil
    }

    public func disconnect() {
        session?.cancel()
        session = nil
        timeout?.cancel()
        timeout = nil
        connection?.cancel()
        connection = nil
        isPaired = false
        onStop?()
        code = String(Int.random(in: 100000...999999))
    }

    public func send(_ message: PlayerMessage) async throws {
        guard isPaired, let connection else { return }
        try await connection.send(message)
    }

    #if canImport(Network)
    private func accept(_ incoming: NWConnection) {
        guard connection == nil else { incoming.cancel(); return }
        let channel = PlayerConnection(incoming)
        accept(channel)
    }
    #else
    private func accept(_ incoming: UInt) {
        guard connection == nil else { ada_player_close(incoming); return }
        accept(PlayerConnection(socket: incoming))
    }
    #endif

    private func accept(_ channel: PlayerConnection) {
        connection = channel
        channel.start()
        timeout = Task { [weak self, weak channel] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, self.connection === channel, !self.isPaired else { return }
            self.disconnect()
            self.status = "Pairing timed out. Try again."
        }
        session = Task { [weak self] in
            do {
                let hello = try await channel.receive(maximumBytes: 4096)
                guard let self, self.connection === channel else { return }
                guard hello.kind == .pair, hello.text == self.code else {
                    throw PlayerConnectError.invalid("Incorrect pairing code.")
                }
                self.timeout?.cancel()
                self.isPaired = true
                self.status = "Connected to AdaEditor"
                try await channel.send(PlayerMessage(.paired))
                while !Task.isCancelled {
                    let message = try await channel.receive()
                    guard self.connection === channel else { return }
                    switch message.kind {
                    case .deploy:
                        guard let project = message.project else { throw PlayerConnectError.invalid("Missing project.") }
                        do {
                            try project.validate()
                            guard let deploy = self.onDeploy else { throw PlayerConnectError.invalid("Player runtime is unavailable.") }
                            try await deploy(project)
                            try Task.checkCancellation()
                            self.status = "Running"
                            try await channel.send(PlayerMessage(.status, text: "running"))
                        } catch {
                            self.status = error.localizedDescription
                            try await channel.send(PlayerMessage(.failure, text: error.localizedDescription))
                        }
                    case .stop:
                        self.onStop?()
                        self.status = "Connected to AdaEditor"
                        try await channel.send(PlayerMessage(.status, text: "stopped"))
                    default: throw PlayerConnectError.invalid("Unexpected player command.")
                    }
                }
            } catch {
                guard let self, self.connection === channel else { return }
                try? await channel.send(PlayerMessage(.failure, text: error.localizedDescription))
                self.disconnect()
                self.status = "\(error.localizedDescription) Waiting for AdaEditor."
            }
        }
    }
}
#endif
