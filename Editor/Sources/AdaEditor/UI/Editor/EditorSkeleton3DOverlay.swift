@_spi(AdaEngine) import AdaEngine
import Foundation
import Math
import Synchronization

/// Preview state shared by UI controls and the post-animation drawing system.
final class EditorSkeleton3DOverlay: Resource, Sendable {
    private let visibility = Mutex(false)
    var isEnabled: Bool {
        get { visibility.withLock { $0 } }
        set { visibility.withLock { $0 = newValue } }
    }

    /// Skip helper nodes while preserving their transforms in the animated global pose.
    static func links(joints: [Int], rig: SkeletalRig) -> [(Int, Int)] {
        let jointSet = Set(joints)
        return joints.compactMap { child in
            guard rig.nodes.indices.contains(child) else { return nil }
            var parent = rig.nodes[child].parentIndex
            var visited: Set<Int> = [child]
            while let index = parent, rig.nodes.indices.contains(index), visited.insert(index).inserted {
                if jointSet.contains(index) { return (index, child) }
                parent = rig.nodes[index].parentIndex
            }
            return nil
        }
    }
}

struct EditorSkeleton3DPlugin: Plugin {
    func setup(in app: AppWorlds) {
        if app.main.getResource(EditorSkeleton3DOverlay.self) == nil {
            app.insertResource(EditorSkeleton3DOverlay())
        }
        app.addSystem(EditorSkeleton3DSystem.self, on: .postUpdate)
    }
}

/// Runs after skinning and transform propagation so bones and mesh use the same frame.
@PlainSystem(dependencies: [.after(SkeletalAnimation3DSystem.self), .after(ChildTransformSystem.self)])
struct EditorSkeleton3DSystem {
    @Query<SkinnedMesh3DComponent> private var skins
    @Query<Entity, ModelAnimation3DComponent, Transform> private var models
    @Res<EditorSkeleton3DOverlay> private var overlay
    @Res<DebugDraw3D> private var debug

    init(world _: World) {}

    func update(context _: UpdateContext) {
        guard overlay.isEnabled else { return }
        models.forEach { root, animation, _ in
            guard let transform = EditorPicking.worldMatrix(for: root) else { return }
            var jointSet: Set<Int> = []
            skins.forEach { skin in
                if skin.modelRoot == root.id { jointSet.formUnion(skin.skin.joints) }
            }
            let joints = jointSet.sorted()
            let pose = animation.player.globalTransforms
            for (parent, child) in EditorSkeleton3DOverlay.links(joints: joints, rig: animation.player.rig)
                where pose.indices.contains(parent) && pose.indices.contains(child) {
                let start = (transform * pose[parent] * Vector4(0, 0, 0, 1)).xyz
                let end = (transform * pose[child] * Vector4(0, 0, 0, 1)).xyz
                debug.line(from: start, to: end, color: Color(0.15, 1, 0.75, 1), depthTested: false)
            }
            let scale = max(0.0001, (transform * Vector4(0.025, 0, 0, 0)).xyz.length)
            for joint in joints where pose.indices.contains(joint) {
                let point = (transform * pose[joint] * Vector4(0, 0, 0, 1)).xyz
                for axis in [Vector3.right, .up, Vector3(0, 0, 1)] {
                    debug.line(from: point - axis * scale, to: point + axis * scale, color: .yellow, depthTested: false)
                }
            }
        }
    }
}
