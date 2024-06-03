//
//  Component.swift
//  AdaEngine.
//
//  Created by v.prusakov on 11/2/21.
//

// TODO: (Vlad) looks like codable isn't great solutions

/// The base component in ECS paradigm.
/// Component contains data described some entity characteristic in the game world, like:
/// color, transformation and etc.
public protocol Component { }

/// Provides the events related to components.
public enum ComponentEvents {

    /// Event raised after a component has been added to an entity,
    public struct DidAdd: Event {
        /// The component type.
        public let componentType: any Component.Type

        /// The component’s entity.
        public let entity: Entity
    }

    /// Event raised after a component has been modified.
    struct DidChange: Event {
        /// The component type.
        public let componentType: any Component.Type

        /// The component’s entity.
        public let entity: Entity
    }

    /// Event raised before a component is removed from an entity.
    struct WillRemove: Event {
        /// The component type.
        public let componentType: any Component.Type

        /// The component’s entity.
        public let entity: Entity
    }
}
