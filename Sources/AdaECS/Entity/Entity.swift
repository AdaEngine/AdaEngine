//
//  Entity.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

// TODO: (Vlad) Make a benchmark
// FIXME: (Vlad) I think we should store components in ComponentTable and avoid storing them in ComponentSet. (Think about after benchmark)

import AdaUtils
import OrderedCollections

/// Describe an entity and his characteristics.
/// Entity in ECS based architecture is main object that holds components.
open class Entity: Identifiable, @unchecked Sendable {

    /// Contains entity name.
    public let name: String

    /// Contains unique identifier of entity.
    public private(set) var id: Int

    /// Contains components specific for current entity.
    @LockProperty public var components: ComponentSet = ComponentSet()

    /// A Boolean that indicates whether the entity is active.
    /// - Note:  AdaEngine doesn’t simulate or render inactive entities.
    public var isActive: Bool = true

    /// Contains reference for world where entity placed.
    public internal(set) weak var world: World?
    
    /// Create a new entity.
    /// Also entity contains next components ``Transform``, ``RelationshipComponent`` and ``Visibility``.
    /// - Note: If you want to use entity without any components use ``EmptyEntity``
    /// - Parameter name: Name of entity. By default is `Entity`.
    public init(name: String = "Entity") {
        self.name = name
        self.id = RID().id
        // swiftlint:disable:next inert_defer
        defer {
            self.components.entity = self
        }
    }

    /// Create a new entity and setup components on init.
    ///
    /// Also entity contains next components ``Transform``, ``RelationshipComponent`` and ``Visibility``.
    /// - Note: If you want to use entity without any components use ``EmptyEntity``
    /// - Parameter name: Name of entity. By default is `Entity`.
    /// - Parameter components: Collection of components.
    public convenience init(
        name: String = "Entity",
        @ComponentsBuilder components: () -> [Component]
    ) {
        self.init(name: name)
        self.components.set(components())
    }

    // MARK: - Codable
    
    /// Create entity from decoder.
    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let id = try container.decode(Int.self, forKey: .id)
        self.init(name: name)
        self.id = id
        self.components = try container.decode(ComponentSet.self, forKey: .components)
        self.components.entity = self
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.components, forKey: .components)
    }
    
    // MARK: - Public
    
    /// Remove entity from scene.
    /// - Note: Entity will removed on next update tick.
    public func removeFromScene(recursively: Bool = false) {
        self.world?.removeEntityOnNextTick(self, recursively: recursively)
    }
}

// MARK: - Hashable

extension Entity: Hashable {
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.id)
    }
}

extension Entity: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case components
    }
}
