//
//  UpdatableProperty.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaUtils
import Logging

/// A protocol that defines a property that can be updated.
public protocol UpdatableProperty {
    /// Update the property.
    ///
    /// - Returns: The property.
    @MainActor func update()
}

/// A protocol that defines a property that can be stored.
protocol PropertyStoragable {
    /// The storage of the property.
    ///
    /// - Returns: The storage of the property.
    @MainActor var storage: UpdatablePropertyStorage { get }
}

/// A storage for a updatable property.
@MainActor
class UpdatablePropertyStorage {
    /// The nodes that need to be updated.
    private(set) var nodes: WeakSet<ViewNode> = []

    /// The name of the property.
    var propertyName: String = ""

    /// Update the property.
    ///
    /// - Returns: The property.
    @MainActor
    func update() {
        nodes.forEach {
            if $0.shouldNotifyAboutChanges {
                Logger(label: "org.adaengine.AdaUI").info("\(type(of: $0.content)): \(propertyName) changed.")
            }

            $0.invalidateContent()
        }
    }

    /// Register a node to update.
    ///
    /// - Parameter viewNode: The view node to register.
    @MainActor
    func registerNodeToUpdate(_ viewNode: ViewNode) {
        nodes.insert(viewNode)
        viewNode.storages.insert(self)
    }
}
