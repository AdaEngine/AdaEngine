//
//  Commands.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

public struct WorldCommands {
    var commands: [WorldCommand] = []

    public mutating func flush(to world: World) {
        for command in commands {
            command.applyToWorld(world)
        }
        self.commands.removeAll()
    }
}

public struct WorldCommand {
    let applyToWorld: (World) -> Void

    public init(applyToWorld: @escaping (World) -> Void) {
        self.applyToWorld = applyToWorld
    }
}

public extension WorldCommands {
    mutating func spawn(
        _ name: String = "",
        @ComponentsBuilder components: @escaping () -> ComponentsBundle
    ) {
        self.commands.append(WorldCommand { world in
            world.spawn(name, bundle: components())
        })
    }

    mutating func spawn<T: ComponentsBundle>(
        _ name: String = "",
        bundle: consuming T
    ) {
        self.commands.append(WorldCommand { [bundle] world in
            world.spawn(name, bundle: bundle)
        })
    }

    mutating func set<T: Component>(_ component: consuming T, for entityId: Entity.ID) {
        self.commands.append(WorldCommand { [component] world in
            world.set(component, for: entityId)
        })
    }

    @inline(__always)
    mutating func remove<T: Component>(_ component: consuming T, for entity: Entity.ID) {
        self.remove(T.identifier, from: entity)
    }

    /// Remove a component of the specified type from an entity.
    /// - Parameter componentType: The type of component to remove.
    /// - Parameter entity: The entity ID to remove the component from.
    @inline(__always)
    mutating func remove<T: Component>(_ componentType: T.Type, from entity: Entity.ID) {
        self.remove(T.identifier, from: entity)
    }

    mutating func remove(_ componentId: ComponentId, from entity: Entity.ID) {
        self.commands.append(WorldCommand { world in
            world.remove(componentId, from: entity)
        })
    }
}
