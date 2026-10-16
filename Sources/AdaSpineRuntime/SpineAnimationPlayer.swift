import AdaSpineBridgeC
import Foundation
import Synchronization

/// The export version must match the bundled Spine 4.2 runtime.
public enum SpineSkeletonFormat: Sendable { case json, binary }

public enum SpineError: Error, Equatable, Sendable {
    case invalidData(String)
    case unknownAnimation(String)
    case unknownSkin(String)
    case invalidTime
}

extension SpineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidData(message): message
        case let .unknownAnimation(name): "Unknown Spine animation '\(name)'."
        case let .unknownSkin(name): "Unknown Spine skin '\(name)'."
        case .invalidTime: "Time and playback speed must be finite and non-negative."
        }
    }
}

public struct SpineVertex: Sendable {
    public let x: Float
    public let y: Float
    public let u: Float
    public let v: Float
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float
    public let darkRed: Float
    public let darkGreen: Float
    public let darkBlue: Float
    public let darkAlpha: Float
}

/// A bone's endpoints in skeleton space, after animation and constraints.
public struct SpineBone: Sendable {
    public let name: String
    public let parentIndex: Int?
    public let isActive: Bool
    public let x: Float
    public let y: Float
    public let endX: Float
    public let endY: Float
}

/// One attachment in Spine's draw order, after skinning and clipping.
public struct SpineDraw: Sendable {
    public enum BlendMode: Int, Sendable { case normal, additive, multiply, screen }
    public let pageIndex: Int
    public let blendMode: BlendMode
    public let premultipliedAlpha: Bool
    public let vertices: [SpineVertex]
    public let indices: [UInt32]
}

/// An independent playback instance. All foreign-runtime access is serialized by a mutex.
/// Create a player per character; sharing this reference intentionally shares playback.
public final class SpineAnimationPlayer: Sendable {
    public let animationNames: [String]
    public let skinNames: [String]
    public let pageNames: [String]
    private let storage: Mutex<Storage>
    // Upstream JSON errors and attachment/sequence IDs use process-wide mutable state.
    // Serialize imports while keeping playback and snapshots locked per character.
    private static let creationLock = Mutex(())

    // This pointer owns the complete C object graph. It never escapes Storage's mutex,
    // and disposal happens only after the last owner releases the player.
    @safe private final class Storage: @unchecked Sendable {
        let pointer: OpaquePointer
        init(_ pointer: OpaquePointer) { unsafe self.pointer = pointer }
        deinit { unsafe ada_spine_dispose(pointer) }
    }

    /// Loads exported skeleton bytes and atlas text without performing IO or allocating GPU resources.
    /// Atlas pages must contain their exported `size:` fields.
    public init(skeleton: Data, atlas: String, format: SpineSkeletonFormat = .json, scale: Float = 1) throws {
        guard !skeleton.isEmpty, skeleton.count <= Int(Int32.max), scale.isFinite, scale > 0,
            !atlas.utf8.contains(0), !atlas.isEmpty else {
            throw SpineError.invalidData("Empty skeleton/atlas or invalid scale.")
        }
        if format == .json {
            guard !skeleton.contains(0),
                let object = try JSONSerialization.jsonObject(with: skeleton) as? [String: Any],
                let bones = object["bones"] as? [[String: Any]], !bones.isEmpty,
                let metadata = object["skeleton"] as? [String: Any],
                let version = metadata["spine"] as? String, version.hasPrefix("4.2.") else {
                throw SpineError.invalidData("Expected a Spine 4.2 skeleton with at least one bone.")
            }
        }
        var error = [CChar](repeating: 0, count: 1_024)
        let pointer = unsafe Self.creationLock.withLock { _ in
            unsafe skeleton.withUnsafeBytes { bytes in
                unsafe atlas.withCString { atlasText in
                    unsafe ada_spine_create(
                        bytes.bindMemory(to: UInt8.self).baseAddress, Int32(skeleton.count), format == .binary ? 1 : 0,
                        atlasText, scale, &error, Int32(error.count)
                    )
                }
            }
        }
        guard let pointer = unsafe pointer else {
            let message = String(decoding: error.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            throw SpineError.invalidData(message)
        }
        self.animationNames = unsafe (0..<ada_spine_animation_count(pointer)).map { unsafe String(cString: ada_spine_animation_name(pointer, $0)) }
        self.skinNames = unsafe (0..<ada_spine_skin_count(pointer)).map { unsafe String(cString: ada_spine_skin_name(pointer, $0)) }
        self.pageNames = unsafe (0..<ada_spine_page_count(pointer)).map { unsafe String(cString: ada_spine_page_name(pointer, $0)) }
        self.storage = unsafe Mutex(Storage(pointer))
    }

    public var time: Float { storage.withLock { unsafe ada_spine_time($0.pointer) } }
    /// A non-looping clip holds its final pose after completing.
    public var isComplete: Bool { storage.withLock { unsafe ada_spine_is_complete($0.pointer) != 0 } }

    /// Starts a clip and crossfades from the current clip. Unknown names leave playback unchanged.
    public func play(_ name: String, repeats: Bool = true, transitionDuration: Float = 0.15) throws(SpineError) {
        guard transitionDuration.isFinite, transitionDuration >= 0 else { throw .invalidTime }
        guard animationNames.contains(name) else { throw .unknownAnimation(name) }
        let found = storage.withLock { state in
            unsafe name.withCString { unsafe ada_spine_play(state.pointer, $0, repeats ? 1 : 0, transitionDuration) != 0 }
        }
        guard found else { throw .unknownAnimation(name) }
    }

    public func setSkin(_ name: String) throws(SpineError) {
        guard skinNames.contains(name) else { throw .unknownSkin(name) }
        let found = storage.withLock { state in unsafe name.withCString { unsafe ada_spine_skin(state.pointer, $0) != 0 } }
        guard found else { throw .unknownSkin(name) }
    }

    /// Advances in seconds. Invalid deltas are ignored, preserving the last valid pose.
    public func advance(by deltaTime: Float) {
        guard deltaTime.isFinite, deltaTime >= 0 else { return }
        storage.withLock { state in
            guard unsafe (ada_spine_time(state.pointer) + deltaTime).isFinite else { return }
            unsafe ada_spine_update(state.pointer, deltaTime)
        }
    }

    public func resetToSetupPose() { storage.withLock { unsafe ada_spine_reset($0.pointer) } }

    /// Copies current bone endpoints for debugging and skeleton overlays.
    public func boneSnapshot() -> [SpineBone] {
        storage.withLock { state in
            let count = unsafe ada_spine_bone_count(state.pointer)
            return (0..<count).map { index in
                let bone = unsafe ada_spine_bone(state.pointer, index)
                return unsafe SpineBone(name: String(cString: bone.name), parentIndex: bone.parentIndex < 0 ? nil : Int(bone.parentIndex),
                                        isActive: bone.active != 0, x: bone.x, y: bone.y, endX: bone.endX, endY: bone.endY)
            }
        }
    }

    /// Returns owned render data, safe to transfer to the render world after the lock is released.
    public func snapshot() -> [SpineDraw] {
        storage.withLock { state in
            let count = unsafe ada_spine_draw_count(state.pointer)
            return (0..<count).map { index in
                let draw = unsafe ada_spine_draw(state.pointer, index)
                let vertices = unsafe UnsafeBufferPointer(start: draw.vertices, count: Int(draw.vertexCount)).map { vertex in
                    SpineVertex(x: vertex.x, y: vertex.y, u: vertex.u, v: vertex.v,
                                red: vertex.r, green: vertex.g, blue: vertex.b, alpha: vertex.a,
                                darkRed: vertex.darkR, darkGreen: vertex.darkG, darkBlue: vertex.darkB, darkAlpha: vertex.darkA)
                }
                let indices = unsafe Array(UnsafeBufferPointer(start: draw.indices, count: Int(draw.indexCount)))
                return unsafe SpineDraw(pageIndex: Int(draw.pageIndex), blendMode: .init(rawValue: Int(draw.blendMode)) ?? .normal,
                                 premultipliedAlpha: draw.premultipliedAlpha != 0, vertices: vertices, indices: indices)
            }
        }
    }
}
