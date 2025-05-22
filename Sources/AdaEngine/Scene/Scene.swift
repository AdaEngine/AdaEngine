//
//  Scene.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

import AdaECS
import AdaUtils
import OrderedCollections

enum SceneSerializationError: Error {
    case invalidExtensionType
    case unsupportedVersion
    case notRegistedObject(String)
}

/// A container that holds the collection of entities for render.
@MainActor @preconcurrency
open class Scene: @preconcurrency Asset, @unchecked Sendable {

    /// Current supported version for mapping scene from file.
    public nonisolated(unsafe) static let currentVersion: Version = "1.0.0"
    
    /// Current scene name.
    public var name: String
    public private(set) var id: UUID
    
    public internal(set) weak var window: UIWindow?
    public internal(set) var viewport: Viewport = Viewport()
    
    public nonisolated(unsafe) var assetMetaInfo: AssetMetaInfo?
    
    public private(set) var world: World
    
    public private(set) var eventManager: EventManager = EventManager.default
    /// Options for content in a scene that can aid debugging.
    public var debugOptions: DebugOptions = []
    
    /// Instance of scene manager which holds this scene.
    public internal(set) weak var sceneManager: SceneManager?

    /// Flag indicate that scene is updating right now.
    private(set) var isUpdating = false

    /// Check the scene will not run earlier.
    private(set) var isReady = false

    private var instantiateDefaultPlugin: Bool = true

    // MARK: - Initialization -
    
    /// Create new scene instance.
    /// - Parameter name: Name of this scene. By default name is `Scene`.
    /// - Parameter instantiateDefaultPlugin:
    public init(name: String? = nil, instantiateDefaultPlugin: Bool = true) {
        self.id = UUID()
        self.name = name ?? "Scene"
        self.world = World()
        self.instantiateDefaultPlugin = instantiateDefaultPlugin
    }
    
    // MARK: - Resource -
    
    public static let assetType: AssetType = .scene
    
    public func encodeContents(with encoder: AssetEncoder) async throws {
        guard encoder.assetMeta.filePath.pathExtension == Self.assetType.fileExtenstion else {
            throw SceneSerializationError.invalidExtensionType
        }
        let sceneData = SceneRepresentation(
            version: Self.currentVersion,
            scene: self.name,
            instantiateDefaultPlugin: self.instantiateDefaultPlugin,
            world: self.world
        )

        try encoder.encode(sceneData)
    }
    
    required public convenience init(asset decoder: AssetDecoder) async throws {
        guard decoder.assetMeta.filePath.pathExtension == Self.assetType.fileExtenstion else {
            throw SceneSerializationError.invalidExtensionType
        }
        
        let sceneData = try decoder.decode(SceneRepresentation.self)
        
        if Self.currentVersion < sceneData.version {
            throw SceneSerializationError.unsupportedVersion
        }
        
        self.init(
            name: sceneData.scene, 
            instantiateDefaultPlugin: sceneData.instantiateDefaultPlugin
        )
        self.world = sceneData.world
    }
    
    // MARK: - Life Cycle

    /// Tells you when the scene is presented.
    ///
    /// - Note: Scene is configured and you can't add new systems to the scene.
    open func sceneDidLoad() { }

    /// Tells you when the scene is about to be removed from a view.
    open func sceneDidMove(to view: SceneView) { }

    /// Tells you when the scene is about to be removed from a view.
    open func sceneWillMove(from view: SceneView) { }

    // MARK: - Internal methods

    func readyIfNeeded() {
        if self.isReady {
            return
        }

        self.ready()
    }
    
    func ready() {
        // TODO: In the future we need minimal scene plugin for headless mode.
        if self.instantiateDefaultPlugin {
            world.addPlugin(DefaultWorldPlugin())
        }
        
        self.isReady = true
        self.world.build()
        self.eventManager.send(SceneEvents.OnReady(scene: self), source: self)
        self.world.insertResource(SceneResource(scene: self))
        self.sceneDidLoad()
    }
    
    /// Update scene world and systems by delta time.
    func update(_ deltaTime: TimeInterval) async {
        if self.isUpdating {
            assertionFailure("Can't update scene twice")
            return
        }
        self.eventManager.send(SceneEvents.Update(scene: self, deltaTime: deltaTime), source: self)
        self.isUpdating = true
        defer { self.isUpdating = false }
        await self.world.update(deltaTime)
    }
}

// MARK: - ECS

public extension Scene {
    
    /// Clear all entities from scene
    @MainActor
    func clearAllEntities() {
        return self.world.clear()
    }
}

// MARK: - World Transform

// TODO: Replace it to GlobalTransform
public extension World {
    /// Returns world transform component of entity.
    func worldTransform(for entity: Entity) -> Transform {
        let worldMatrix = self.worldTransformMatrix(for: entity)
        return Transform(matrix: worldMatrix)
    }
    
    /// Returns world transform matrix of entity.
    func worldTransformMatrix(for entity: Entity) -> Transform3D {
        var transform = Transform3D.identity
        
        if let parent = entity.parent {
            transform = self.worldTransformMatrix(for: parent)
        }
        
        guard let entityTransform = entity.components[GlobalTransform.self] else {
            return transform
        }
        
        return transform * entityTransform.matrix
    }
}

// MARK: - EventSource

extension Scene: @preconcurrency EventSource {
    
    /// Receives events of the given type.
    /// - Parameters event: The type of the event, like `CollisionEvents.Began.Self`.
    /// - Parameters completion: A closure to call with the event.
    /// - Returns: A cancellable object. You should store it in memory, to recieve events.
    public func subscribe<E>(
        to event: E.Type,
        on eventSource: EventSource?,
        completion: @escaping (E) -> Void
    ) -> Cancellable where E : Event {
        return self.eventManager.subscribe(to: event, on: eventSource ?? self, completion: completion)
    }
}

public extension Scene {
    struct DebugOptions: OptionSet, Sendable {
        public var rawValue: UInt16
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        /// Draw physics collision shapes for physics object.
        public static let showPhysicsShapes = DebugOptions(rawValue: 1 << 0)

        public static let showFPS = DebugOptions(rawValue: 1 << 1)

        public static let showBoundingBoxes = DebugOptions(rawValue: 1 << 2)
    }
}

/// Events the scene triggers.
public enum SceneEvents {
    
    /// An event triggered once when scene is ready to use and will starts update soon.
    public struct OnReady: Event {
        public let scene: Scene
    }
    
    /// An event triggered once per frame interval that you can use to execute custom logic for each frame.
    public struct Update: Event {

        /// The updated scene.
        public let scene: Scene

        /// The elapsed time since the last update.
        public let deltaTime: TimeInterval
    }

}

@Component
struct SceneResource {
    unowned let scene: Scene
}

public extension WorldUpdateContext {
    var scene: Scene {
        self.world.getResource(SceneResource.self)!.scene
    }
}

private extension Scene {
    struct SceneRepresentation: Codable {
        let version: Version
        let scene: String
        let instantiateDefaultPlugin: Bool
        let world: AdaECS.World
    }
}