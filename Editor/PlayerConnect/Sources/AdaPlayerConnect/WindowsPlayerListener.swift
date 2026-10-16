#if os(Windows)
import CWindowsPlayer
import Dispatch
import Foundation

@MainActor
final class WindowsPlayerListener {
    private var socket: UInt = .max
    private var task: Task<Void, Never>?
    let port: UInt16

    init(onConnection: @escaping @MainActor (UInt) -> Void) throws {
        var port: UInt16 = 0
        let socket = ada_player_listen(&port)
        guard socket != .max else { throw PlayerConnectError.invalid("Could not listen for Ada Studio. Check your firewall.") }
        self.socket = socket
        self.port = port
        task = Task { [weak self] in
            while !Task.isCancelled {
                let incoming: UInt = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(returning: ada_player_accept(socket))
                    }
                }
                guard let self, self.socket == socket, !Task.isCancelled else { ada_player_close(incoming); return }
                if incoming == .max { return }
                onConnection(incoming)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if socket != .max { ada_player_close(socket); socket = .max }
    }
}
#endif
