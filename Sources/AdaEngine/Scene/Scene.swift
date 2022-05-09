//
//  Scene.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Foundation
import OrderedCollections

public final class Scene {
    
    public var name: String
    public private(set) var id: UUID
    
    var entities: OrderedSet<Entity> = []

    var activeCamera: Camera
    
    var systems: [System] = []
    
    public weak var sceneManager: SceneManager?
    
    public init(name: String = "") {
        self.id = UUID()
        self.name = name.isEmpty ? "Scene" : name
        let cameraEntity = Entity()
        
        let cameraComponent = Camera()
        cameraEntity.components[Camera.self] = cameraComponent
        self.entities.append(cameraEntity)
        
        self.activeCamera = cameraComponent
        
        defer {
            self.addSystem(ScriptComponentUpdateSystem.self)
            self.addSystem(CameraSystem.self)
            self.addSystem(Circle2DRenderSystem.self)
        }
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        
        let entities = try container.decode([Entity].self, forKey: .entities)
        
        let systemNames = try container.decodeIfPresent([String].self, forKey: .systems) ?? []
        var systems = [System]()
        
        for key in systemNames {
            guard let type = SystemStorage.getRegistredSystem(for: key) else {
                continue
            }
            
            systems.append(type.init(scene: self))
        }
        
        self.systems = systems
        
        for entity in entities {
            self.addEntity(entity)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.entities, forKey: .entities)
        try container.encode(self.systems.map { type(of: $0).swiftName }, forKey: .systems)
    }
    
    func update(_ deltaTime: TimeInterval) {
        for system in self.systems {
            system.update(context: SystemUpdateContext(scene: self, deltaTime: deltaTime))
        }
    }
    
    func physicsUpdate(_ deltaTime: TimeInterval) {
        for entity in entities.elements {
            entity.physicsUpdate(deltaTime)
        }
    }
    
    public func addSystem<T: System>(_ system: T.Type) {
        self.systems.append(system.init(scene: self))
    }
    

}

// MARK: - Query

public struct QueryPredicate<Value> {
    var fetch: (Value) -> Bool
}

extension QueryPredicate {
    static func has<T: Component>(_ type: T.Type) -> QueryPredicate<Entity> {
        QueryPredicate<Entity> { entity in
            return entity.components.has(type)
        }
    }
    
    static func && (lhs: QueryPredicate<Value>, rhs: QueryPredicate<Value>) -> QueryPredicate<Value> {
        QueryPredicate { value in
            lhs.fetch(value) && rhs.fetch(value)
        }
    }
    
    static func || (lhs: QueryPredicate<Value>, rhs: QueryPredicate<Value>) -> QueryPredicate<Value> {
        QueryPredicate { value in
            lhs.fetch(value) || rhs.fetch(value)
        }
    }
}

public struct EntityQuery {
    
    let predicate: QueryPredicate<Entity>
    
    public init(_ predicate: QueryPredicate<Entity>) {
        self.predicate = predicate
    }
}

public extension Scene {
    func performQuery(_ query: EntityQuery) -> [Entity] {
        return entities.flatMap { $0.performQuery(query) }
    }
}

// MARK: - Entity

public extension Scene {
    func addEntity(_ entity: Entity) {
        precondition(entity.scene == nil, "Entity has scene reference, can't be added")
        entity.scene = self
        self.entities.updateOrAppend(entity)
    }
    
    func removeEntity(_ entity: Entity) {
        self.entities.remove(entity)
        entity.scene = nil
    }
}

extension Scene: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, entities, systems
    }
}

class ViewportEntity: Entity {
    
    init(scene: Scene, size: Vector2i, name: String? = nil) {
        super.init(name: name ?? "ViewportEntity-\(scene.name)")
        
        self.components[ViewportComponent.self] = ViewportComponent(scene: scene, size: size)
    }
    
    public required convenience init(from decoder: Decoder) throws {
        fatalError()
    }
    
}

struct ViewportComponent: Component {
    var scene: Scene
    var size: Vector2i
}

struct ViewportComponentSystem: System {
    
    static let query = EntityQuery(.has(ViewportComponent.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach {
            $0.components[ViewportComponent.self]?.scene.update(context.deltaTime)
        }
    }
}
