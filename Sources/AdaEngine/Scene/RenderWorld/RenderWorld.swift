//
//  RenderScene.swift
//  
//
//  Created by v.prusakov on 3/21/23.
//

import Foundation

public final class RenderWorld {
    
    let renderGraphExecutor = RenderGraphExecutor()
    public let renderGraph = RenderGraph()
    
    private let scene: Scene = Scene(name: "RenderWorld")
    
    let renderQueue: DispatchQueue = DispatchQueue(
        label: "adaengine.renderworld",
        qos: .userInitiated
    )
    
    public var world: World {
        self.scene.world
    }
    
    /// Add new system to the scene.
    public func addSystem<T: System>(_ systemType: T.Type) {
        scene.addSystem(systemType)
    }
    
    /// Add new scene plugin to the scene.
    public func addPlugin<T: ScenePlugin>(_ plugin: T) {
        self.scene.addPlugin(plugin)
    }
    
    public func addEntity(_ entity: Entity) {
        self.scene.addEntity(entity)
    }
    
    func update(_ deltaTime: TimeInterval) throws {
        self.scene.update(deltaTime)
        try self.renderGraphExecutor.execute(self.renderGraph, in: self.world)
        
        self.scene.world.clear()
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
