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

// MARK: - State Storage

/// A container that keeps state storages for a specific view node.
@MainActor
final class ViewStateContainer {
    private var storages: [String: UpdatablePropertyStorage] = [:]

    func storage<Value>(
        for key: String,
        initialValue: @autoclosure () -> StateStorage<Value>
    ) -> StateStorage<Value> {
        if let storage = storages[key] as? StateStorage<Value> {
            return storage
        }

        let storage = initialValue()
        storages[key] = storage
        return storage
    }
}

@MainActor
protocol ViewStateBindable {
    func bind(to container: ViewStateContainer, key: String)
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

    nonisolated init() {

    }

    /// Update the property.
    ///
    /// - Returns: The property.
    func update() {
        nodes.forEach {
            if $0.shouldNotifyAboutChanges {
                // Logger(label: "org.adaengine.AdaUI")
                    // .info("\(type(of: $0.content)): \(propertyName) changed. \(UnsafeRawPointer(bitPattern: &self.value))")
            }

            $0.invalidateContent()
            if let containerView = $0.owner?.containerView {
                containerView.setNeedsDisplay(in: $0.absoluteFrame())
            }
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
