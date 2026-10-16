//
//  VoxelAnimation3D.swift
//  AdaEngine
//

import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import Math

/// Animation data of one imported voxel node, keyed by MagicaVoxel animation frame numbers.
public struct VoxelNodeAnimation: Sendable {
    /// A local transform at a frame.
    public struct TransformKey: Sendable {
        public var frame: Int
        public var transform: Transform

        public init(frame: Int, transform: Transform) {
            self.frame = frame
            self.transform = transform
        }
    }

    /// A model (mesh) shown from a frame on, with the local offset that places its pivot.
    public struct ShapeKey: Sendable {
        public var frame: Int
        /// Index into ``ModelAsset3D/meshes``.
        public var meshIndex: Int
        public var offset: Vector3

        public init(frame: Int, meshIndex: Int, offset: Vector3) {
            self.frame = frame
            self.meshIndex = meshIndex
            self.offset = offset
        }
    }

    /// Keys sorted by frame. Position and scale interpolate linearly and rotation spherically; the pose holds after the last key.
    public var transformKeys: [TransformKey]
    /// Keys sorted by frame. Models switch without interpolation.
    public var shapeKeys: [ShapeKey]

    public init(transformKeys: [TransformKey] = [], shapeKeys: [ShapeKey] = []) {
        self.transformKeys = transformKeys.sorted { $0.frame < $1.frame }
        self.shapeKeys = shapeKeys.sorted { $0.frame < $1.frame }
    }

    /// The highest frame number used by any key.
    public var lastFrame: Int {
        max(transformKeys.last?.frame ?? 0, shapeKeys.last?.frame ?? 0)
    }

    /// Local transform at a (fractional) frame, or `nil` when the node has no transform keys.
    public func transform(at frame: Float) -> Transform? {
        guard let first = transformKeys.first, let last = transformKeys.last else {
            return nil
        }
        if frame <= Float(first.frame) {
            return first.transform
        }
        if frame >= Float(last.frame) {
            return last.transform
        }
        guard let upperIndex = transformKeys.firstIndex(where: { Float($0.frame) > frame }) else {
            return last.transform
        }
        let lower = transformKeys[upperIndex - 1]
        let upper = transformKeys[upperIndex]
        let t = (frame - Float(lower.frame)) / Float(upper.frame - lower.frame)
        return Transform(
            rotation: Self.slerp(lower.transform.rotation, upper.transform.rotation, t),
            scale: lerp(lower.transform.scale, upper.transform.scale, t),
            position: lerp(lower.transform.position, upper.transform.position, t)
        )
    }

    /// The shape shown at a frame: the last key at or before it, or the first key before the animation starts.
    public func shape(at frame: Float) -> ShapeKey? {
        guard let first = shapeKeys.first else {
            return nil
        }
        return shapeKeys.last { Float($0.frame) <= frame } ?? first
    }

    /// Spherical interpolation along the shortest arc.
    public static func slerp(_ from: Quat, _ to: Quat, _ t: Float) -> Quat {
        var target = to
        var cosine = from.dot(to)
        if cosine < 0 {
            target = Quat(x: -to.x, y: -to.y, z: -to.z, w: -to.w)
            cosine = -cosine
        }
        // Nearly parallel quaternions: normalized linear interpolation avoids dividing by a tiny sine.
        if cosine > 0.9995 {
            return Quat(
                x: from.x + (target.x - from.x) * t,
                y: from.y + (target.y - from.y) * t,
                z: from.z + (target.z - from.z) * t,
                w: from.w + (target.w - from.w) * t
            ).normalized
        }
        let angle = acos(cosine)
        let sine = sin(angle)
        let a = sin((1 - t) * angle) / sine
        let b = sin(t * angle) / sine
        return Quat(
            x: from.x * a + target.x * b,
            y: from.y * a + target.y * b,
            z: from.z * a + target.z * b,
            w: from.w * a + target.w * b
        ).normalized
    }
}

/// Timeline shared by all animated nodes of one voxel model instance. Lives on the model root entity.
public struct VoxelAnimationPlayback3DComponent: Component {
    public var isPlaying: Bool
    public var repeats: Bool
    /// Playback speed multiplier.
    public var speed: Double
    public var framesPerSecond: Double
    /// Length of the timeline in frames; the clock wraps (or stops) here.
    public var frameCount: Int
    /// Current time in seconds.
    public var time: Double

    public init(framesPerSecond: Double = 30, frameCount: Int, isPlaying: Bool = true, repeats: Bool = true, speed: Double = 1, time: Double = 0) {
        self.framesPerSecond = framesPerSecond
        self.frameCount = frameCount
        self.isPlaying = isPlaying
        self.repeats = repeats
        self.speed = speed
        self.time = time
    }

    /// The current animation frame, fractional.
    public var currentFrame: Float {
        Float(time * framesPerSecond)
    }

    /// Advances the clock, wrapping or clamping at the end of the timeline.
    public mutating func advance(by delta: Double) {
        guard isPlaying, frameCount > 0, framesPerSecond > 0, speed.isFinite, delta.isFinite else {
            return
        }
        let duration = Double(frameCount) / framesPerSecond
        time += delta * speed
        if repeats {
            time = time.truncatingRemainder(dividingBy: duration)
            if time < 0 {
                time += duration
            }
        } else {
            time = min(max(time, 0), duration)
            if time >= duration || time <= 0, speed != 0 {
                isPlaying = false
            }
        }
    }
}

/// Animates the local transform of an instantiated voxel node (an `nTRN` with several frames).
public struct VoxelTransformAnimation3DComponent: Component {
    public let modelRoot: Entity.ID
    public let animation: VoxelNodeAnimation

    public init(modelRoot: Entity.ID, animation: VoxelNodeAnimation) {
        self.modelRoot = modelRoot
        self.animation = animation
    }
}

/// Swaps the mesh of an instantiated voxel shape over time (an `nSHP` with several models).
public struct VoxelShapeAnimation3DComponent: Component {
    public let modelRoot: Entity.ID
    public let animation: VoxelNodeAnimation
    /// Meshes addressed by ``VoxelNodeAnimation/ShapeKey/meshIndex``.
    public let meshes: [Int: Mesh]
    /// Mesh index currently shown, so unchanged frames do not rewrite the mesh component.
    var appliedMeshIndex: Int?

    public init(modelRoot: Entity.ID, animation: VoxelNodeAnimation, meshes: [Int: Mesh]) {
        self.modelRoot = modelRoot
        self.animation = animation
        self.meshes = meshes
    }
}

/// Advances voxel animation clocks and applies keyed transforms and mesh switches before transform propagation.
@PlainSystem(dependencies: [.before(TransformSystem.self)])
public struct VoxelAnimation3DSystem {
    @Query<Ref<VoxelAnimationPlayback3DComponent>, Entity> private var playbacks
    @Query<VoxelTransformAnimation3DComponent, Ref<Transform>> private var transforms
    @Query<Ref<VoxelShapeAnimation3DComponent>, Ref<Transform>, Ref<Mesh3DComponent>> private var shapes
    @Res<DeltaTime> private var time

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        var frames: [Entity.ID: Float] = [:]
        playbacks.forEach { playback, root in
            var value = playback.wrappedValue
            value.advance(by: Double(time.deltaTime))
            playback.wrappedValue = value
            frames[root.id] = value.currentFrame
        }

        transforms.forEach { binding, transform in
            guard let frame = frames[binding.modelRoot], let next = binding.animation.transform(at: frame),
                transform.wrappedValue != next
            else {
                return
            }
            transform.wrappedValue = next
        }

        shapes.forEach { shape, transform, mesh in
            var binding = shape.wrappedValue
            guard let frame = frames[binding.modelRoot], let key = binding.animation.shape(at: frame),
                binding.appliedMeshIndex != key.meshIndex, let next = binding.meshes[key.meshIndex]
            else {
                return
            }
            var component = mesh.wrappedValue
            component.mesh = next
            mesh.wrappedValue = component
            var local = transform.wrappedValue
            local.position = key.offset
            transform.wrappedValue = local
            binding.appliedMeshIndex = key.meshIndex
            shape.wrappedValue = binding
        }
    }
}
