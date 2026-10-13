@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation
import Yams

@Observable
@MainActor
final class EditorParticleEffectEditorModel {
    let document: EditorAssetDocument
    private(set) var descriptor = ParticleEffectDescriptor()
    var selectedEmitter = 0
    private(set) var error: String?
    private(set) var status = "Loading particle effect…"
    private(set) var previewEffect: ParticleEffect?
    private(set) var previewRevision = 0
    var isPlaying = true
    var restartCount = 0
    let previewStatistics = EditorParticlePreviewStatistics()
    @ObservationIgnored private var savedData: Data?
    @ObservationIgnored private var undoStack: [ParticleEffectDescriptor] = []
    @ObservationIgnored private var redoStack: [ParticleEffectDescriptor] = []
    @ObservationIgnored private var previewTask: Task<Void, Never>?

    init(document: EditorAssetDocument) {
        self.document = document
        reload()
    }

    var emitter: ParticleEmitterDescriptor { descriptor.emitters[min(max(0, selectedEmitter), descriptor.emitters.count - 1)] }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var url: URL? { document.absolutePath.map { URL(fileURLWithPath: $0) } }

    func reload() {
        do {
            guard let url else { throw ParticleEffectError.invalid("Particle resource is unavailable.") }
            let data = try Data(contentsOf: url)
            guard data.count <= 2 * 1024 * 1024 else { throw ParticleEffectError.invalid("Particle resources must be under 2 MB.") }
            let loaded = try YAMLDecoder().decode(ParticleEffectDescriptor.self, from: data)
            descriptor = loaded
            savedData = data
            selectedEmitter = min(selectedEmitter, loaded.emitters.count - 1)
            undoStack = []
            redoStack = []
            error = nil
            status = "Saved · \(loaded.emitters.count) emitter(s)"
            refreshPreview()
        } catch { self.error = Self.diagnostic(error) }
    }

    @discardableResult
    func updateEmitter(_ edit: (inout ParticleEmitterDescriptor) -> Void) -> Bool {
        var candidate = descriptor
        edit(&candidate.emitters[selectedEmitter])
        return commit(candidate)
    }

    func addEmitter() {
        guard descriptor.emitters.count < 16 else { return }
        var candidate = descriptor
        candidate.emitters.append(.init(name: "Emitter \(candidate.emitters.count + 1)"))
        if commit(candidate) { selectedEmitter = candidate.emitters.count - 1 }
    }

    func removeEmitter() {
        guard descriptor.emitters.count > 1 else { return }
        var candidate = descriptor
        candidate.emitters.remove(at: selectedEmitter)
        if commit(candidate) { selectedEmitter = min(selectedEmitter, candidate.emitters.count - 1) }
    }

    func undo() {
        guard let candidate = undoStack.last, persist(candidate) else { return }
        undoStack.removeLast()
        redoStack.append(descriptor)
        adopt(candidate)
    }

    func redo() {
        guard let candidate = redoStack.last, persist(candidate) else { return }
        redoStack.removeLast()
        undoStack.append(descriptor)
        adopt(candidate)
    }

    func addCurveKey(_ path: WritableKeyPath<ParticleEmitterDescriptor, ParticleCurve>) {
        var keys = emitter[keyPath: path].keys
        guard keys.count < 32 else { return }
        if keys.count == 1 {
            let time: Float = keys[0].time < 0.5 ? 1 : 0
            keys.append(.init(time: time, value: keys[0].value))
        } else {
            let index = (1..<keys.count).max { keys[$0].time - keys[$0 - 1].time < keys[$1].time - keys[$1 - 1].time } ?? 1
            keys.append(.init(time: (keys[index].time + keys[index - 1].time) * 0.5, value: (keys[index].value + keys[index - 1].value) * 0.5))
        }
        keys.sort { $0.time < $1.time }
        updateEmitter { $0[keyPath: path].keys = keys }
    }

    func moveCurveKey(_ path: WritableKeyPath<ParticleEmitterDescriptor, ParticleCurve>, index: Int, time: Float, value: Float) {
        let keys = emitter[keyPath: path].keys
        guard keys.indices.contains(index), time.isFinite, value.isFinite else { return }
        let lower = index == 0 ? 0 : keys[index - 1].time + 0.001
        let upper = index == keys.count - 1 ? 1 : keys[index + 1].time - 0.001
        guard lower <= upper else { return }
        updateEmitter { $0[keyPath: path].keys[index] = .init(time: min(upper, max(lower, time)), value: min(100, max(0, value))) }
    }

    func cancelPreview() { previewTask?.cancel(); previewTask = nil }

    func refreshPreview() {
        previewTask?.cancel()
        guard let url else { return }
        let expectedDescriptor = descriptor
        let expectedData = savedData
        previewTask = Task { [weak self] in
            do {
                guard let expectedData, try Data(contentsOf: url) == expectedData else {
                    throw ParticleEffectError.invalid("The file changed on disk. Reload to preview its new settings.")
                }
                let effect = try await AssetsManager.loadFresh(ParticleEffect.self, at: url.path)
                try Task.checkCancellation()
                guard effect.descriptor == expectedDescriptor else {
                    throw ParticleEffectError.invalid("The file changed while loading. Reload to preview its new settings.")
                }
                self?.previewEffect = effect
                self?.previewRevision &+= 1
            } catch is CancellationError { return }
            catch { self?.error = Self.diagnostic(error) }
        }
    }

    private func commit(_ candidate: ParticleEffectDescriptor) -> Bool {
        guard candidate != descriptor else { return true }
        guard persist(candidate) else { return false }
        undoStack.append(descriptor)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack = []
        adopt(candidate)
        return true
    }

    private func persist(_ candidate: ParticleEffectDescriptor) -> Bool {
        do {
            try candidate.validate()
            guard let url, let savedData, try Data(contentsOf: url) == savedData else {
                throw ParticleEffectError.invalid("The file changed on disk. Reload before editing; your changes were not written.")
            }
            let data = Data(try YAMLEncoder().encode(candidate).utf8)
            try data.write(to: url, options: .atomic)
            self.savedData = data
            error = nil
            status = "Saved · \(candidate.emitters.count) emitter(s)"
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    private func adopt(_ candidate: ParticleEffectDescriptor) {
        descriptor = candidate
        selectedEmitter = min(selectedEmitter, candidate.emitters.count - 1)
        refreshPreview()
    }

    private static func diagnostic(_ error: any Error) -> String {
        let context: DecodingError.Context
        switch error {
        case DecodingError.typeMismatch(_, let value), DecodingError.valueNotFound(_, let value), DecodingError.dataCorrupted(let value):
            context = value
        case DecodingError.keyNotFound(let key, let value):
            return "Missing \(key.stringValue): \(value.debugDescription)"
        default: return error.localizedDescription
        }
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
    }
}

extension EditorWorkbenchViewModel {
    func particleEffectModel(for document: EditorAssetDocument) -> EditorParticleEffectEditorModel {
        if let model = particleEffectModels[document.id] { return model }
        let model = EditorParticleEffectEditorModel(document: document)
        particleEffectModels[document.id] = model
        return model
    }

    @discardableResult
    func addParticleEffect(_ asset: EditorAssetDocument, to documentID: String) -> Bool {
        guard let reference = asset.assetReference, asset.kind == .particleEffect,
            let document = sceneDocument(id: documentID), !document.isReadOnly, document.sceneModel != nil else { return false }
        selectDocument(id: documentID)
        updateSceneModelDocument(id: documentID, status: "Particle effect added") { scene in
            let entity = scene.addEntity(template: .empty, parentID: scene.editor?.selectedEntity)
            guard let index = scene.entities.firstIndex(where: { $0.id == entity.id }) else { return }
            scene.entities[index].name = URL(fileURLWithPath: asset.title).deletingPathExtension().lastPathComponent
            scene.entities[index].components[EditorBuiltInComponentType.particleEmitter] = [
                "effect": .string(reference), "isEmitting": .bool(true), "isPaused": .bool(false), "restartCount": .int(0),
            ]
        }
        return true
    }
}
