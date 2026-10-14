#if !canImport(Network)
import AdaEngine
import Foundation
import Observation

/// Keep unavailable device preview explicit on hosts without Apple Network.
@Observable @MainActor
final class EditorPlayerSession {
    private(set) var connected = false
    private(set) var isBusy = false
    private(set) var isRunning = false
    let status = "AdaPlayer device connections are currently available on Apple platforms."
    var onOutput: ((String) -> Void)?
    var onState: ((Bool) -> Void)?
    var onConnected: (() -> Void)?

    func deploy(_ project: URL) {
        onOutput?(status)
    }

    func stop() {
        disconnect()
    }

    func disconnect() {
        onState?(false)
    }
}

struct EditorPlayerPairingView: View {
    let session: EditorPlayerSession
    let project: URL

    var body: some View {
        Text(session.status).padding(.all, 24)
    }
}
#endif
