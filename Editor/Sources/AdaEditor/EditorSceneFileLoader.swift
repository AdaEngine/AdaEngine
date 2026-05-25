@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorSceneLoadSummary: Equatable, Sendable {
    var entityCount: Int
    var warnings: [String]

    static let empty = EditorSceneLoadSummary(entityCount: 0, warnings: [])
}

struct EditorSceneRuntimeLoadResult: Equatable, Sendable {
    var entityCount: Int
    var warnings: [String]
    var entitiesByEditorID: [String: Entity.ID]
    var editorIDsByEntityID: [Entity.ID: String]

    static let empty = EditorSceneRuntimeLoadResult(entityCount: 0, warnings: [], entitiesByEditorID: [:], editorIDsByEntityID: [:])
}

enum EditorSceneFileLoader {
    static func summary(from content: String) -> EditorSceneLoadSummary {
        do {
            let sceneModel = try EditorSceneModel.decode(from: content)
            return EditorSceneLoadSummary(entityCount: sceneModel.entities.count, warnings: [])
        } catch {
            return EditorSceneLoadSummary(entityCount: 0, warnings: [error.localizedDescription])
        }
    }

    static func model(from content: String) -> EditorSceneModel? {
        try? EditorSceneModel.decode(from: content)
    }

    @discardableResult
    @MainActor
    static func load(content: String, into world: World) -> EditorSceneRuntimeLoadResult {
        do {
            registerEditorSceneComponents()
            let sceneModel = try EditorSceneModel.decode(from: content)
            return instantiate(sceneModel, in: world)
        } catch {
            return .emptyWithWarnings([error.localizedDescription])
        }
    }

    @discardableResult
    @MainActor
    static func load(model sceneModel: EditorSceneModel, into world: World) -> EditorSceneRuntimeLoadResult {
        registerEditorSceneComponents()
        return instantiate(sceneModel, in: world)
    }

    @MainActor
    private static func registerEditorSceneComponents() {
        EditorComponentRegistry.registerBuiltIns()
        EditorGizmo.registerComponent()
    }

    @MainActor
    private static func instantiate(_ sceneModel: EditorSceneModel, in world: World) -> EditorSceneRuntimeLoadResult {
        var warnings: [String] = []
        var entitiesByEditorID: [String: Entity] = [:]
        var runtimeEntityIDsByEditorID: [String: Entity.ID] = [:]
        var editorIDsByRuntimeEntityID: [Entity.ID: String] = [:]

        for sceneEntity in sceneModel.entities {
            let entity = world.spawn(sceneEntity.name)
            entity.isActive = sceneEntity.enabled
            entitiesByEditorID[sceneEntity.id] = entity
            runtimeEntityIDsByEditorID[sceneEntity.id] = entity.id
            editorIDsByRuntimeEntityID[entity.id] = sceneEntity.id

            for (componentName, componentPayload) in sceneEntity.components {
                guard RuntimeTypeRegistry.componentType(named: componentName) != nil
                    || EditorComponentRegistry.descriptor(named: componentName) != nil else {
                    warnings.append("Unknown component: \(componentName)")
                    continue
                }

                do {
                    if let component = try EditorComponentRegistry.decode(typeName: componentName, payload: componentPayload) {
                        insertComponent(component, into: entity, in: world)
                    } else {
                        warnings.append("Component is not decodable: \(componentName)")
                    }
                } catch {
                    warnings.append("Failed to decode \(componentName): \(error.localizedDescription)")
                }
            }
        }

        for sceneEntity in sceneModel.entities {
            guard let parentID = sceneEntity.parent, !parentID.isEmpty else {
                continue
            }

            guard let entity = entitiesByEditorID[sceneEntity.id] else {
                continue
            }

            guard let parent = entitiesByEditorID[parentID] else {
                warnings.append("Missing parent \(parentID) for entity \(sceneEntity.id)")
                continue
            }

            parent.addChild(entity)
        }

        return EditorSceneRuntimeLoadResult(
            entityCount: sceneModel.entities.count,
            warnings: warnings,
            entitiesByEditorID: runtimeEntityIDsByEditorID,
            editorIDsByEntityID: editorIDsByRuntimeEntityID
        )
    }

    private static func insertComponent(_ component: any Component, into entity: Entity, in world: World) {
        world.insert(component, for: entity.id)
    }
}

private extension EditorSceneRuntimeLoadResult {
    static func emptyWithWarnings(_ warnings: [String]) -> EditorSceneRuntimeLoadResult {
        EditorSceneRuntimeLoadResult(entityCount: 0, warnings: warnings, entitiesByEditorID: [:], editorIDsByEntityID: [:])
    }
}
