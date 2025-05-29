//
//  Scene.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

import AdaAssets
import AdaECS
import AdaUtils
import Foundation
import AdaUI
import OrderedCollections

enum SceneSerializationError: Error {
    case invalidExtensionType
    case unsupportedVersion
    case notRegistedObject(String)
}

// TODO: (Vlad) MainActor can still in problem. Should we use it? 

/// A container that holds the collection of entities for render.
open class Scene: Asset, @unchecked Sendable {

    public typealias ID = UUID

    /// Current supported version for mapping scene from file.
    public nonisolated(unsafe) static let currentVersion: Version = "1.0.0"
    
    /// Current scene name.
    public var name: String

    /// Current scene id.
    public private(set) var id: ID

    /// Current window for scene.
    public internal(set) weak var window: UIWindow?
    
    public nonisolated(unsafe) var assetMetaInfo: AssetMetaInfo?
    
    /// World for scene.
    public private(set) var world: World
    
    /// Event manager for scene.
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

    public init(from world: World, instantiateDefaultPlugin: Bool = true) {
        self.id = UUID()
        self.name = "Scene"
        self.world = world
        self.instantiateDefaultPlugin = instantiateDefaultPlugin
    }
    
    // MARK: - Resource -
    public required convenience init(from assetDecoder: any AssetDecoder) throws {
        guard Self.extensions().contains(where: { assetDecoder.assetMeta.filePath.pathExtension == $0 }) else {
            throw SceneSerializationError.invalidExtensionType
        }
        
        let scene = try assetDecoder.decode(SceneSerialization.self)
        
        if Self.currentVersion < scene.version {
            throw SceneSerializationError.unsupportedVersion
        }
        
        self.init(
            name: scene.scene,
            instantiateDefaultPlugin: scene.instantiateDefaultPlugin
        )
        self.world = scene.world
    }
    
    public func encodeContents(with assetEncoder: any AssetEncoder) throws {
        guard Self.extensions().contains(where: { assetEncoder.assetMeta.filePath.pathExtension == $0 }) else {
            throw SceneSerializationError.invalidExtensionType
        }
        
        try assetEncoder.encode(
            SceneSerialization(
                version: Self.currentVersion,
                scene: name,
                instantiateDefaultPlugin: instantiateDefaultPlugin,
                world: world
            )
        )
    }
    
    public static func extensions() -> [String] {
        ["ascn", "scene", "scn"]
    }

    public func update(_ newScene: Scene) async throws {
        self.world = newScene.world
        self.eventManager = newScene.eventManager
        self.debugOptions = newScene.debugOptions
        self.instantiateDefaultPlugin = newScene.instantiateDefaultPlugin
    }
    
    // MARK: - Life Cycle

    /// Tells you when the scene is presented.
    ///
    /// - Note: Scene is configured and you can't add new systems to the scene.
    @MainActor open func sceneDidLoad() { }

    /// Tells you when the scene is about to be removed from a view.
    @MainActor open func sceneDidMove(to view: SceneView) { }

    /// Tells you when the scene is about to be removed from a view.
    @MainActor open func sceneWillMove(from view: SceneView) { }

    // MARK: - Internal methods

    @MainActor func readyIfNeeded() {
        if self.isReady {
            return
        }

        self.ready()
    }
    
    @MainActor func ready() {
        self.isReady = true
        self.world.build()
        self.eventManager.send(SceneEvents.OnReady(scene: self), source: self)
        self.world.insertResource(SceneResource(scene: self))
        self.sceneDidLoad()
    }
    
    /// Update scene world and systems by delta time.
    @MainActor func update(_ deltaTime: AdaUtils.TimeInterval) async {
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

// MARK: - EventSource

extension Scene: EventSource {
    
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
        public let deltaTime: AdaUtils.TimeInterval
    }

}

struct SceneResource: Resource {
    unowned let scene: Scene
}

public extension WorldUpdateContext {
    var scene: Scene? {
        self.world.getResource(SceneResource.self)?.scene
    }
}

private extension Scene {
    struct SceneSerialization: Codable {
        let version: Version
        let scene: String
        let instantiateDefaultPlugin: Bool
        let world: AdaECS.World
    }
}
