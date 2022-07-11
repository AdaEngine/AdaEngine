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

    public internal(set) var activeCamera: Camera
    
    public internal(set) weak var window: Window?
    
    var systems: [System] = []
    private(set) var world: World
    
    public private(set) var physicsWorld2D: PhysicsWorld2D
    
    public var viewportRelativeWindowSize: Bool = true
    
    // Options for content in a scene that can aid debugging.
    public var debugOptions: DebugOptions = []
    public var debugPhysicsColor: Color = .green
    
    private var _viewportSize: Size = .zero
    public var viewportSize: Size {
        get {
            if self.viewportRelativeWindowSize {
                return self.window?.frame.size ?? .zero
            }
            
            return self._viewportSize
        }
        
        set {
            if self.viewportRelativeWindowSize {
               print("You set viewport size when scene size relative to window. That not affect getter.")
            }
            
            self._viewportSize = newValue
        }
    }
    
    public weak var sceneManager: SceneManager?
    
    public init(name: String = "") {
        self.id = UUID()
        self.name = name.isEmpty ? "Scene" : name
        self.world = World()
        self.physicsWorld2D = PhysicsWorld2D()
        
        let cameraEntity = Entity()
        
        let cameraComponent = Camera()
        cameraEntity.components += cameraComponent
        self.world.appendEntity(cameraEntity)
        
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
//        try container.encode(self.entities, forKey: .entities)
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
        self.addSystem(Render2DSystem.self)
        self.addSystem(Physics2DSystem.self)
        self.addSystem(ViewContainerSystem.self)
        
        self.isReady = true
    }
    
    func update(_ deltaTime: TimeInterval) {
        for system in self.systems {
            system.update(context: SceneUpdateContext(scene: self, deltaTime: deltaTime))
        }
    }
}

// MARK: - ECS

public extension Scene {
    func performQuery(_ query: EntityQuery) -> QueryResult {
        return self.world.performQuery(query)
    }
}

// MARK: - Entity

public extension Scene {
    func addEntity(_ entity: Entity) {
        precondition(entity.scene == nil, "Entity has scene reference, can't be added")
        entity.scene = self
        self.world.appendEntity(entity)
    }
    
    func removeEntity(_ entity: Entity) {
        self.world.removeEntity(entity)
        entity.scene = nil
    }
}

extension Scene: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, entities, systems
    }
}

public extension Scene {
    struct DebugOptions: OptionSet {
        public var rawValue: UInt16
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        public static let showPhysicsShapes = DebugOptions(rawValue: 1 << 0)
        public static let showFPS = DebugOptions(rawValue: 1 << 1)
    }
}
