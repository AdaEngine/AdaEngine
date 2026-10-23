import AdaEngine
import AdaScriptCompilerCore
import Foundation
#if os(WASI)
import JavaScriptKit
#endif

/// Editor commands mutate the live scene world. Only committed edits leave the iframe.
/// The editor camera is transient; authored cameras and exported files stay intact.
@MainActor
final class PlayerEditorBridge {
    private var entities: [String: Entity] = [:]
    private var cameraEntity: Entity?
    #if os(WASI)
    private var callback: JSClosure?
    #endif

    func install(entities: [String: Entity], in world: World) {
        guard PlayerBrowserSession.editMode else { return }
        self.entities = entities
        let cameras = entities.values.filter { $0.components[Camera.self]?.isActive == true && Self.visible($0) }
            .sorted {
                let first = $0.components[Camera.self]?.renderOrder ?? 0, second = $1.components[Camera.self]?.renderOrder ?? 0
                return first == second ? $0.id < $1.id : first < second
            }
        // Preserve camera composition on opening. Navigation controls the final
        // active view; each authored camera remains a separate editable entity.
        for source in cameras {
            guard var camera = source.components[Camera.self] else { continue }
            let editor = world.spawn("Studio editor camera")
            camera.isActive = true
            editor.components += camera
            editor.components += Transform(matrix: Self.matrix(source))
            if let environment = source.components[Environment3D.self] { editor.components += environment }
            if let graph = source.components[CameraRenderGraph.self] { editor.components += graph }
            SceneRuntimeBootstrap.prepareCamera(on: editor, in: world)
            cameraEntity = editor
            source.components[Camera.self]?.isActive = false
        }
        #if os(WASI)
        let handler = JSClosure { [weak self] values in
            let input = values.first?.string ?? "{}"
            let result = MainActor.assumeIsolated { self?.execute(input) ?? "{\"error\":\"Editor closed\"}" }
            return .string(result)
        }
        callback = handler
        JSObject.global["__adaStudioEditor"] = handler.jsValue
        #endif
    }

    private func execute(_ input: String) -> String {
        do {
            guard PlayerBrowserSession.editMode,
                let data = input.data(using: .utf8), data.count < 16_384,
                let command = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let type = command["type"] as? String,
                let cameraEntity, var camera = cameraEntity.components[Camera.self] else {
                throw AdaWebPlayerProjectError.invalid("Editor camera unavailable")
            }
            switch type {
            case "transform":
                guard let id = command["id"] as? String, let entity = entities[id],
                    let value = command["transform"] as? [String: Any] else {
                    throw AdaWebPlayerProjectError.invalid("Unknown scene entity")
                }
                let position = try numbers(value["position"], count: 3)
                let rotation = try numbers(value["rotation"], count: 4)
                let scale = try numbers(value["scale"], count: 3)
                let length = rotation.reduce(Float.zero) { $0 + $1 * $1 }.squareRoot()
                guard length > 0.00001 else { throw AdaWebPlayerProjectError.invalid("Invalid rotation") }
                entity.components += Transform(
                    rotation: Quat(x: rotation[0] / length, y: rotation[1] / length, z: rotation[2] / length, w: rotation[3] / length),
                    scale: Vector3(scale[0], scale[1], scale[2]), position: Vector3(position[0], position[1], position[2])
                )
            case "camera":
                let position = try numbers(command["position"], count: 3)
                let rotation = try numbers(command["rotation"], count: 4)
                let length = rotation.reduce(Float.zero) { $0 + $1 * $1 }.squareRoot()
                guard length > 0.00001 else { throw AdaWebPlayerProjectError.invalid("Invalid camera rotation") }
                cameraEntity.components += Transform(
                    rotation: Quat(x: rotation[0] / length, y: rotation[1] / length, z: rotation[2] / length, w: rotation[3] / length),
                    position: Vector3(position[0], position[1], position[2])
                )
                if case var .orthographic(projection) = camera.projection, let zoom = command["zoom"] as? Double, zoom.isFinite {
                    projection.scale = Float(min(10_000, max(0.1, zoom)))
                    camera.projection = .orthographic(projection)
                    cameraEntity.components += camera
                }
            case "state": break
            default: throw AdaWebPlayerProjectError.invalid("Unknown editor command")
            }
            let cameraMatrix = Self.matrix(cameraEntity)
            let projection = camera.projection.makeClipView()
            var result: [String: Any] = [
                "camera": Self.array(cameraMatrix), "projection": Self.array(projection),
                "entities": entities.sorted { $0.key < $1.key }.map { id, entity -> [String: Any] in
                    let transform = entity.components[Transform.self] ?? Transform()
                    let bounds = Self.bounds(entity)
                    return ["id": id, "matrix": Self.array(Self.matrix(entity)),
                        "parent": Self.array(entity.parent.map(Self.matrix) ?? .identity),
                        "position": Self.array(transform.position), "rotation": [transform.rotation.x, transform.rotation.y, transform.rotation.z, transform.rotation.w],
                        "scale": Self.array(transform.scale), "min": Self.array(bounds.min), "max": Self.array(bounds.max),
                        "visible": Self.visible(entity),
                        "pickable": entity.components[Sprite.self] != nil || entity.components[Mesh3DComponent.self] != nil || entity.components[Model3DSource.self] != nil,
                        "sprite": entity.components[Sprite.self] != nil]
                }
            ]
            if case let .orthographic(projection) = camera.projection { result["zoom"] = projection.scale }
            let encoded = try JSONSerialization.data(withJSONObject: result)
            return String(decoding: encoded, as: UTF8.self)
        } catch {
            let encoded = (try? JSONSerialization.data(withJSONObject: ["error": String(describing: error)])) ?? Data()
            return String(decoding: encoded, as: UTF8.self)
        }
    }

    private func numbers(_ value: Any?, count: Int) throws -> [Float] {
        guard let result = value as? [Double], result.count == count,
            result.allSatisfy({ $0.isFinite && abs($0) < 1_000_000 }) else {
            throw AdaWebPlayerProjectError.invalid("Invalid editor coordinates")
        }
        return result.map(Float.init)
    }

    private static func matrix(_ entity: Entity) -> Transform3D {
        var result = entity.components[Transform.self]?.matrix ?? .identity
        var ancestor = entity.parent
        var visited: Set<Entity.ID> = [entity.id]
        while let parent = ancestor, visited.insert(parent.id).inserted {
            result = (parent.components[Transform.self]?.matrix ?? .identity) * result
            ancestor = parent.parent
        }
        return result
    }

    private static func visible(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        var visited: Set<Entity.ID> = []
        while let node = current {
            guard visited.insert(node.id).inserted, node.isActive, node.components[Visibility.self] != .hidden else { return false }
            current = node.parent
        }
        return true
    }

    private static func bounds(_ entity: Entity) -> AABB {
        if let mesh = entity.components[Mesh3DComponent.self] { return mesh.mesh.bounds }
        if let component = entity.components[BoundingComponent.self], case let .aabb(bounds) = component.bounds { return bounds }
        if let sprite = entity.components[Sprite.self] {
            let size = sprite.size?.asVector2 ?? sprite.texture?.asset?.size.toSize().asVector2 ?? .one
            return AABB(center: Vector3(-sprite.anchor.x * size.x, -sprite.anchor.y * size.y, 0),
                halfExtents: Vector3(size.x / 2, size.y / 2, 0.01))
        }
        // Imported model meshes live below their authored entity. Aggregate child
        // boxes in the authored local space so picking/focus select the model root.
        let inverse = matrix(entity).inverse
        var points: [Vector3] = []
        func collect(_ node: Entity) {
            if let mesh = node.components[Mesh3DComponent.self] {
                let box = mesh.mesh.bounds, transform = inverse * matrix(node)
                for x in [box.min.x, box.max.x] { for y in [box.min.y, box.max.y] { for z in [box.min.z, box.max.z] {
                    points.append((transform * Vector4(x, y, z, 1)).xyz)
                } } }
            }
            for child in node.children { collect(child) }
        }
        for child in entity.children { collect(child) }
        if let first = points.first {
            var low = first, high = first
            for point in points { for axis in 0..<3 { low[axis] = min(low[axis], point[axis]); high[axis] = max(high[axis], point[axis]) } }
            return AABB(center: (low + high) / 2, halfExtents: (high - low) / 2)
        }
        return AABB(center: .zero, halfExtents: Vector3(0.35))
    }

    private static func array(_ vector: Vector3) -> [Float] { [vector.x, vector.y, vector.z] }
    private static func array(_ matrix: Transform3D) -> [Float] {
        [matrix.x, matrix.y, matrix.z, matrix.w].flatMap { [$0.x, $0.y, $0.z, $0.w] }
    }
}
