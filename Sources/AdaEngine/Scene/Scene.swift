//
//  Scene.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import OrderedCollections

public final class Scene {
    
    public var name: String
    public private(set) var id: UUID
    
    var entities: OrderedSet<Entity> = []

    public internal(set) var activeCamera: Camera
    
    public internal(set) weak var window: Window?
    
    var systems: [System] = []
    
    public var viewportSize: Size = .zero
    
    public weak var sceneManager: SceneManager?
    
    public init(name: String = "") {
        self.id = UUID()
        self.name = name.isEmpty ? "Scene" : name
        let cameraEntity = Entity()
        
        let cameraComponent = Camera()
        cameraEntity.components[Camera.self] = cameraComponent
        self.entities.append(cameraEntity)
        
        self.activeCamera = cameraComponent
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
            
            // FIXME: We should initiate scene after engine run
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
    
    public func addSystem<T: System>(_ systemType: T.Type) {
        let system = systemType.init(scene: self)
        self.systems.append(system)
    }
    
    // MARK: - Internal methods
    
    /// Check the scene will not run earlier
    var isReady = false
    
    func ready() {
        // Add base systems
        self.addSystem(ScriptComponentUpdateSystem.self)
        self.addSystem(CameraSystem.self)
        self.addSystem(Circle2DRenderSystem.self)
        self.addSystem(ViewContainerSystem.self)
        
        self.isReady = true
    }
    
    func update(_ deltaTime: TimeInterval) {
        for system in self.systems {
            system.update(context: SceneUpdateContext(scene: self, deltaTime: deltaTime))
        }
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
