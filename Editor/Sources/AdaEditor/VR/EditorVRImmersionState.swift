/// Every ordinary entry is full immersion; mixed requires an explicit request.
enum EditorVRImmersionMode: Sendable { case full, mixed
    var preservesPassthrough: Bool { self == .mixed }
}

struct EditorVRImmersionState {
    private(set) var mode: EditorVRImmersionMode = .full
    private(set) var requestsEntry = false

    mutating func request(_ mode: EditorVRImmersionMode = .full, allowed: Bool) {
        guard allowed, !requestsEntry else { return }
        self.mode = mode
        requestsEntry = true
    }

    mutating func finishEntryAttempt() { requestsEntry = false }
}
