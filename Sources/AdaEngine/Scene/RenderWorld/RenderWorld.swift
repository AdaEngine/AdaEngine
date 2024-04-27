//
//  RenderScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

// FIXME: Should run on render thread.

/// RenderWorld store entities for rendering. Each update tick entities removed from RenderWorld.
@RenderGraphActor
public final class RenderWorld {
    
    let renderGraphExecutor = RenderGraphExecutor()
    
    public let renderGraph: RenderGraph = RenderGraph()

    private let scene: Scene = Scene(name: "RenderWorld")

    public var world: World {
        get async {
            return await self.scene.world
        }
    }
    
    /// Add a new system to the scene.
    public func addSystem<T: System>(_ systemType: T.Type) async {
        await scene.addSystem(systemType)
    }
    
    /// Add a new scene plugin to the scene.
    public func addPlugin<T: ScenePlugin>(_ plugin: T) async {
        await self.scene.addPlugin(plugin)
    }
    
    /// Add a new entity to render world.
    public func addEntity(_ entity: Entity) async {
        await self.scene.addEntity(entity)
    }
    
    func update(_ deltaTime: TimeInterval) async throws {
        await self.scene.update(deltaTime)
        try await self.renderGraphExecutor.execute(self.renderGraph, in: self.world)

        await self.scene.world.clear()
    }
}

@propertyWrapper
struct Atomic<Value> {
    
    private var value: Value
    private let lock = NSLock()
    
    init(wrappedValue value: Value) {
        self.value = value
    }
    
    var wrappedValue: Value {
        get { return load() }
        set { store(newValue: newValue) }
    }
    
    func load() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    
    mutating func store(newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
