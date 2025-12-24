//
//  Commands.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

import AdaUtils
import Collections
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public final class WorldCommandQueue: @unchecked Sendable {
    var commands: Deque<WorldCommand> = []
    let lock = RecursiveLock()

    public var isEmpty: Bool {
        commands.isEmpty
    }

    public init() {}

    init(_ commands: Deque<WorldCommand>) {
        self.commands = commands
    }

    public func push(_ command: @escaping @Sendable (World) -> Void) {
        lock.sync {
            commands.append(WorldCommand(applyToWorld: command))
        }
    }

    public func apply(to world: World) {
        world.flushCommands()
        applyAndDrop(to: world)
    }

    public func copy() -> WorldCommandQueue {
        WorldCommandQueue(commands)
    }

    func applyAndDrop(to world: World) {
        while let drop = commands.popFirst() {
            drop.applyToWorld(world)
        }
    }
}

public struct WorldCommand: Sendable {
    let applyToWorld: @Sendable (World) -> Void

    public init(applyToWorld: @escaping @Sendable (World) -> Void) {
        self.applyToWorld = applyToWorld
    }
}

@propertyWrapper
public final class Commands: @unchecked Sendable {
    public var entities: Entities
    public private(set) var queue: WorldCommandQueue

    public var isEmpty: Bool {
        self.queue.isEmpty
    }

    public var wrappedValue: Commands {
        self
    }

    public init() {
        entities = .init()
        queue = .init()
    }

    public init(entities: Entities, commandsQueue: WorldCommandQueue) {
        self.entities = entities
        self.queue = commandsQueue
    }
}

extension Commands: SystemParameter {
    public convenience init(from world: World) {
        self.init(entities: world.entities, commandsQueue: world.commandQueue)
    }

    public func update(from world: World) {
        self.entities = world.entities
    }

    public func finish(_ world: World) {
        queue.apply(to: world)
    }
}

public extension Commands {
    func append(_ commands: Commands) {
        self.queue.commands.append(contentsOf: commands.queue.commands)
    }

    @discardableResult
    func spawn(
        _ name: String = "",
        @ComponentsBuilder components: @escaping @Sendable () -> ComponentsBundle
    ) -> EntityCommands {
        let entity = entities.allocate(with: name)
        self.queue.push { world in
            world.insertNewEntity(entity, components: components().components)
        }
        return EntityCommands(queue: queue, entityId: entity.id)
    }

    @discardableResult
    func spawn<T: ComponentsBundle>(
        _ name: String = "",
        bundle: consuming T
    ) -> EntityCommands {
        let entity = entities.allocate(with: name)
        self.queue.push { [bundle] world in
            world.insertNewEntity(entity, components: bundle.components)
        }
        return EntityCommands(queue: queue, entityId: entity.id)
    }

    @discardableResult
    func spawn(_ name: String = "") -> EntityCommands {
        let entity = entities.allocate(with: name)
        self.queue.push { world in
            world.insertNewEntity(entity, components: [])
        }
        return EntityCommands(queue: queue, entityId: entity.id)
    }

    @discardableResult
    func insertEntity(_ entity: Entity) -> EntityCommands {
        entities.addNotAllocatedEntity(entity)
        queue.push { world in
            world.addEntity(entity)
        }
        return EntityCommands(queue: queue, entityId: entity.id)
    }

    @discardableResult
    func entity(_ entity: Entity.ID) -> EntityCommands {
        EntityCommands(queue: queue, entityId: entity)
    }

    func insertResource<T: Resource>(_ resource: T) {
        self.queue.push {
            $0.insertResource(resource)
        }
    }

    func removeResource<T: Resource>(_ resource: T.Type) {
        self.queue.push {
            $0.removeResource(T.self)
        }
    }
}

@safe
public final class EntityCommands {
    var queue: WorldCommandQueue
    public let entityId: Entity.ID

    init(queue: WorldCommandQueue, entityId: Entity.ID) {
        self.queue = queue
        self.entityId = entityId
    }
}

public extension EntityCommands {
    @discardableResult
    func insert<T: Component>(_ component: consuming T) -> Self {
        self.queue.push { [component, entityId] world in
            world.insert(component, for: entityId)
        }
        return self
    }

    @discardableResult
    func remove(_ componentId: ComponentId, from entity: Entity.ID) -> Self {
        self.queue.push { world in
            world.remove(componentId, from: entity)
        }
        return self
    }

    @discardableResult
    @inline(__always)
    func addChild(
        _ child: Entity
    ) -> Self {
        self.queue.push { [entityId] world in
            let entity = world.getEntityByID(entityId)
            world.addEntity(child)
            entity?.addChild(child)
        }
        return self
    }

    @inline(__always)
    func removeFromWorld(recursively: Bool = false) {
        self.queue.push { [entityId] world in
            world.removeEntity(entityId, recursively: recursively)
        }
    }

    @discardableResult
    @inline(__always)
    func remove<T: Component>(_ component: consuming T) -> Self {
        self.remove(T.identifier, from: entityId)
    }

    /// Remove a component of the specified type from an entity.
    /// - Parameter componentType: The type of component to remove.
    /// - Parameter entity: The entity ID to remove the component from.
    @discardableResult
    @inline(__always)
    func remove<T: Component>(_ componentType: T.Type, from entity: Entity.ID) -> Self {
        self.remove(T.identifier, from: entity)
    }
}
