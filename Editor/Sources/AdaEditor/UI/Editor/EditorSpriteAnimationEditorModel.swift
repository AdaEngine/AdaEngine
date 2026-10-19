@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation
import Yams

/// Edits one `.spriteanim` resource. Every accepted edit is written to disk straight away, like the Particle FX editor.
@Observable
@MainActor
final class EditorSpriteAnimationEditorModel {
    let document: EditorAssetDocument
    private(set) var descriptor = SpriteAnimationSetDescriptor(image: "")
    var selectedClip = 0
    private(set) var error: String?
    private(set) var status = "Loading sprite animation…"
    private(set) var previewSet: SpriteAnimationSet?
    private(set) var previewRevision = 0
    var isPlaying = true
    var restartCount = 0
    let previewStatistics = EditorSpriteAnimationPreviewStatistics()
    @ObservationIgnored private var savedData: Data?
    @ObservationIgnored private var undoStack: [SpriteAnimationSetDescriptor] = []
    @ObservationIgnored private var redoStack: [SpriteAnimationSetDescriptor] = []
    @ObservationIgnored private var previewTask: Task<Void, Never>?

    static let maximumClips = 64
    static let maximumFramesPerClip = 512

    init(document: EditorAssetDocument) {
        self.document = document
        reload()
    }

    var clip: SpriteAnimationClip? { descriptor.clips.indices.contains(selectedClip) ? descriptor.clips[selectedClip] : nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var url: URL? { document.absolutePath.map { URL(fileURLWithPath: $0) } }

    func reload() {
        do {
            guard let url else { throw SpriteAnimationError.invalid("Sprite animation resource is unavailable.") }
            let data = try Data(contentsOf: url)
            guard data.count <= 2 * 1024 * 1024 else { throw SpriteAnimationError.invalid("Sprite animation resources must be under 2 MB.") }
            let loaded = try YAMLDecoder().decode(SpriteAnimationSetDescriptor.self, from: data)
            descriptor = loaded
            savedData = data
            selectedClip = min(selectedClip, max(0, loaded.clips.count - 1))
            undoStack = []
            redoStack = []
            error = nil
            status = Self.summary(of: loaded)
            refreshPreview()
        } catch { self.error = Self.diagnostic(error) }
    }

    // MARK: - Editing

    @discardableResult
    func updateDescriptor(_ edit: (inout SpriteAnimationSetDescriptor) -> Void) -> Bool {
        var candidate = descriptor
        edit(&candidate)
        return commit(candidate)
    }

    @discardableResult
    func updateClip(_ edit: (inout SpriteAnimationClip) -> Void) -> Bool {
        guard descriptor.clips.indices.contains(selectedClip) else { return false }
        var candidate = descriptor
        edit(&candidate.clips[selectedClip])
        return commit(candidate)
    }

    func addClip() {
        guard descriptor.clips.count < Self.maximumClips else { return }
        var candidate = descriptor
        var number = candidate.clips.count + 1
        while candidate.clips.contains(where: { $0.name == "Clip \(number)" }) { number += 1 }
        candidate.clips.append(SpriteAnimationClip(name: "Clip \(number)", frames: []))
        if commit(candidate) { selectedClip = candidate.clips.count - 1 }
    }

    func removeClip() {
        guard descriptor.clips.indices.contains(selectedClip) else { return }
        var candidate = descriptor
        candidate.clips.remove(at: selectedClip)
        if commit(candidate) { selectedClip = min(selectedClip, max(0, candidate.clips.count - 1)) }
    }

    /// Appends grid cells `from...through` of one row, in order.
    func addGridFrames(row: Int, from: Int, through: Int) {
        guard row >= 0, from >= 0, through >= from else {
            error = "Row and columns must be non-negative, and the last column cannot precede the first."
            return
        }
        guard let clip, clip.frames.count + (through - from + 1) <= Self.maximumFramesPerClip else {
            error = "A clip holds at most \(Self.maximumFramesPerClip) frames."
            return
        }
        updateClip { clip in
            clip.frames.append(contentsOf: (from...through).map { SpriteAnimationFrame(atlasCoordinates: PointInt(x: $0, y: row)) })
        }
    }

    func removeFrame(at index: Int) {
        guard let clip, clip.frames.indices.contains(index) else { return }
        updateClip { $0.frames.remove(at: index) }
    }

    func moveFrame(at index: Int, by offset: Int) {
        guard let clip, clip.frames.indices.contains(index), clip.frames.indices.contains(index + offset) else { return }
        updateClip { $0.frames.swapAt(index, index + offset) }
    }

    func updateFrame(at index: Int, _ edit: (inout SpriteAnimationFrame) -> Void) {
        guard let clip, clip.frames.indices.contains(index) else { return }
        updateClip { edit(&$0.frames[index]) }
    }

    /// Replaces the image and clips with those of an Aseprite sheet export (`--data … --format json-array`).
    /// `relativePath` is the JSON file's path relative to this resource.
    func importAseprite(from relativePath: String) {
        do {
            guard let url else { throw SpriteAnimationError.invalid("Sprite animation resource is unavailable.") }
            let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw SpriteAnimationError.invalid("Enter the path of the Aseprite JSON, relative to this resource.") }
            let base = url.deletingLastPathComponent()
            let jsonURL = URL(fileURLWithPath: trimmed, relativeTo: base).standardizedFileURL
            let attributes = try FileManager.default.attributesOfItem(atPath: jsonURL.path)
            guard (attributes[.size] as? Int ?? 0) <= 8 * 1024 * 1024 else { throw SpriteAnimationError.invalid("The Aseprite JSON is over 8 MB.") }
            let sheet = try AsepriteSheet(data: Data(contentsOf: jsonURL))
            guard let image = sheet.image, !image.isEmpty else { throw AsepriteImportError.malformed("the sheet does not name its image") }
            let imageURL = URL(fileURLWithPath: image, relativeTo: jsonURL.deletingLastPathComponent()).standardizedFileURL
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                throw SpriteAnimationError.invalid("The sheet's image \(image) is not next to the JSON.")
            }
            let imported = try sheet.descriptor(imagePath: Self.relativePath(from: base, to: imageURL))
            guard commit(imported) else { return }
            selectedClip = 0
            status = "Imported \(imported.clips.count) clip(s) from \(jsonURL.lastPathComponent)"
        } catch { self.error = error.localizedDescription }
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

    // MARK: - Preview

    func cancelPreview() { previewTask?.cancel(); previewTask = nil }

    func refreshPreview() {
        previewTask?.cancel()
        guard let url, !descriptor.image.isEmpty else {
            previewSet = nil
            previewRevision &+= 1
            return
        }
        let expectedDescriptor = descriptor
        let expectedData = savedData
        previewTask = Task { [weak self] in
            do {
                guard let expectedData, try Data(contentsOf: url) == expectedData else {
                    throw SpriteAnimationError.invalid("The file changed on disk. Reload to preview its new settings.")
                }
                let set = try await AssetsManager.loadFresh(SpriteAnimationSet.self, at: url.path)
                try Task.checkCancellation()
                guard set.descriptor == expectedDescriptor else {
                    throw SpriteAnimationError.invalid("The file changed while loading. Reload to preview its new settings.")
                }
                self?.previewSet = set
                self?.previewRevision &+= 1
            } catch is CancellationError { return }
            catch { self?.error = Self.diagnostic(error) }
        }
    }

    // MARK: - Persistence

    private func commit(_ candidate: SpriteAnimationSetDescriptor) -> Bool {
        guard candidate != descriptor else { return true }
        guard persist(candidate) else { return false }
        undoStack.append(descriptor)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack = []
        adopt(candidate)
        return true
    }

    private func persist(_ candidate: SpriteAnimationSetDescriptor) -> Bool {
        do {
            // A new resource has no image yet; its clips can already be authored.
            try candidate.validate(requiresImage: false)
            guard let url, let savedData, try Data(contentsOf: url) == savedData else {
                throw SpriteAnimationError.invalid("The file changed on disk. Reload before editing; your changes were not written.")
            }
            let data = Data(try YAMLEncoder().encode(candidate).utf8)
            try data.write(to: url, options: .atomic)
            self.savedData = data
            error = nil
            status = Self.summary(of: candidate)
            return true
        } catch { self.error = Self.diagnostic(error); return false }
    }

    private func adopt(_ candidate: SpriteAnimationSetDescriptor) {
        descriptor = candidate
        selectedClip = min(selectedClip, max(0, candidate.clips.count - 1))
        refreshPreview()
    }

    // MARK: - Helpers

    private static func summary(of descriptor: SpriteAnimationSetDescriptor) -> String {
        "Saved · \(descriptor.clips.count) clip(s)"
    }

    /// `target` relative to the directory `base`, using `..` where it leaves it.
    static func relativePath(from base: URL, to target: URL) -> String {
        let from = base.standardizedFileURL.pathComponents
        let to = target.standardizedFileURL.pathComponents
        var shared = 0
        while shared < min(from.count, to.count), from[shared] == to[shared] { shared += 1 }
        let parts = Array(repeating: "..", count: from.count - shared) + to[shared...]
        return parts.joined(separator: "/")
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

/// Playback telemetry has its own observation boundary so the form is not rebuilt every frame.
@Observable
@MainActor
final class EditorSpriteAnimationPreviewStatistics {
    private(set) var frameText = ""
    @ObservationIgnored private var elapsed: Double = 0
    private static let interval: Double = 0.1

    func record(frame: Int?, count: Int, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        elapsed += deltaTime
        guard elapsed >= Self.interval else { return }
        elapsed.formTruncatingRemainder(dividingBy: Self.interval)
        let text = frame.map { "Frame \($0 + 1) / \(count)" } ?? ""
        if frameText != text { frameText = text }
    }
}

extension EditorWorkbenchViewModel {
    func spriteAnimationModel(for document: EditorAssetDocument) -> EditorSpriteAnimationEditorModel {
        if let model = spriteAnimationModels[document.id] { return model }
        let model = EditorSpriteAnimationEditorModel(document: document)
        spriteAnimationModels[document.id] = model
        return model
    }

    /// Adds an entity with a Sprite and a SpriteAnimator playing the resource's first clip.
    @discardableResult
    func addSpriteAnimation(_ asset: EditorAssetDocument, to documentID: String) -> Bool {
        guard let reference = asset.assetReference, asset.kind == .spriteAnimation,
            let document = sceneDocument(id: documentID), !document.isReadOnly, document.sceneModel != nil else { return false }
        selectDocument(id: documentID)
        updateSceneModelDocument(id: documentID, status: "Sprite animation added") { scene in
            let entity = scene.addEntity(template: .empty, parentID: scene.editor?.selectedEntity)
            guard let index = scene.entities.firstIndex(where: { $0.id == entity.id }) else { return }
            scene.entities[index].name = URL(fileURLWithPath: asset.title).deletingPathExtension().lastPathComponent
            scene.entities[index].components[EditorBuiltInComponentType.sprite] = EditorComponentRegistry.defaultPayload(
                for: EditorBuiltInComponentType.sprite
            )
            scene.entities[index].components[EditorBuiltInComponentType.spriteAnimator] = [
                "animations": .string(reference), "currentClip": .string(""), "isPlaying": .bool(true), "speed": .double(1), "restartCount": .int(0),
            ]
        }
        return true
    }
}
