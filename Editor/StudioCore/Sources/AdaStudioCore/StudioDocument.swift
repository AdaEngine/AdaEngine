import Foundation
import Observation

/// One transactional edit path for manual operations, agent tools and undo.
@MainActor @Observable
public final class StudioDocument {
    public private(set) var snapshot: StudioSnapshot
    public private(set) var generation = 0
    public private(set) var selection: String?
    @ObservationIgnored private var undoStack: [StudioSnapshot] = []
    @ObservationIgnored private var redoStack: [StudioSnapshot] = []
    public init(snapshot: StudioSnapshot) throws { try snapshot.validate(); self.snapshot = snapshot }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public func select(_ id: String?) { selection = id }

    public func edit(_ update: (inout StudioSnapshot) throws -> Void) throws {
        var next = snapshot
        try update(&next)
        try next.validate()
        guard next != snapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll(); snapshot = next; generation += 1
    }

    public func write(_ path: String, data: Data) throws {
        try edit { snapshot in
            if let index = snapshot.files.firstIndex(where: { $0.path == path }) { snapshot.files[index].data = data }
            else { snapshot.files.append(StudioFile(path: path, data: data)) }
        }
    }
    public func delete(_ path: String) throws { try edit { $0.files.removeAll { $0.path == path } } }
    public func append(_ message: StudioMessage) throws {
        var next = snapshot; next.messages.append(message); try next.validate()
        snapshot = next; generation += 1
    }
    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        var restored = previous; restored.messages = snapshot.messages
        snapshot = restored; generation += 1
    }
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        var restored = next; restored.messages = snapshot.messages
        snapshot = restored; generation += 1
    }
    public func replace(_ snapshot: StudioSnapshot) throws { try edit { $0 = snapshot } }
}

@MainActor public protocol StudioCloudTransport {
    func request(path: String, method: String, body: Data?) async throws -> Data
    func stream(path: String, body: Data, onEvent: @escaping @MainActor (StudioValue) -> Void) async throws
    func cancelRequests()
}

@MainActor public protocol StudioRecoveryStorage {
    func load(account: String, project: String) async throws -> Data?
    func save(account: String, project: String, data: Data) async throws
    func remove(account: String, project: String) async throws
}

@MainActor public protocol StudioFileAccess {
    func open(accept: String) async throws -> StudioFile?
    func download(name: String, data: Data) throws
}

@MainActor public protocol StudioPreview {
    func load(_ snapshot: StudioSnapshot) async throws
    func stop()
    func capture() async throws -> String
    func input(_ event: StudioValue) async throws
    var logs: [String] { get }
}
