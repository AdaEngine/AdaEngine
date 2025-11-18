//
//  Commands.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

public struct WorldCommandQueue: Sendable {
    var commands: ContiguousArray<WorldCommand> = []

    public var isEmpty: Bool {
        commands.isEmpty
    }

    public init() {}

    public mutating func push(_ command: @escaping @Sendable (World) -> Void) {
        commands.append(WorldCommand(applyToWorld: command))
    }

    public mutating func apply(to world: World) {
        world.flushCommands()

        while let drop = commands.popLast() {
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

    public func update(from world: consuming World) {
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

    func spawn(
        _ name: String = "",
        @ComponentsBuilder components: @escaping @Sendable () -> ComponentsBundle
    ) {
        self.queue.push { world in
            world.spawn(name, bundle: components())
        }
    }

    func spawn<T: ComponentsBundle>(
        _ name: String = "",
        bundle: consuming T
    ) {
        self.queue.push { [bundle] world in
            world.spawn(name, bundle: bundle)
        }
    }

    func entity(_ entity: Entity.ID) -> EntityCommands {
        EntityCommands(queue: &queue, entityId: entity)
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

public final class EntityCommands {
    var queue: UnsafeMutablePointer<WorldCommandQueue>
    public let entityId: Entity.ID

    init(queue: UnsafeMutablePointer<WorldCommandQueue>, entityId: Entity.ID) {
        self.queue = queue
        self.entityId = entityId
    }
}

public extension EntityCommands {
    func insert<T: Component>(_ component: consuming T) -> Self {
        self.queue.pointee.push { [component, entityId] world in
            world.insert(component, for: entityId)
        }
        return self
    }

    func remove(_ componentId: ComponentId, from entity: Entity.ID) -> Self {
        self.queue.pointee.push { world in
            world.remove(componentId, from: entity)
        }
        return self
    }

    @inline(__always)
    func remove<T: Component>(_ component: consuming T) -> Self {
        self.remove(T.identifier, from: entityId)
    }

    /// Remove a component of the specified type from an entity.
    /// - Parameter componentType: The type of component to remove.
    /// - Parameter entity: The entity ID to remove the component from.
    @inline(__always)
    func remove<T: Component>(_ componentType: T.Type, from entity: Entity.ID) -> Self {
        self.remove(T.identifier, from: entity)
    }
}
