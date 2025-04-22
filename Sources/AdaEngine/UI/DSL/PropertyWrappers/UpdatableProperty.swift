//
//  UpdatableProperty.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Logging

public protocol UpdatableProperty {
    @MainActor func update()
}

protocol PropertyStoragable {
    @MainActor var storage: UpdatablePropertyStorage { get }
}

@MainActor
class UpdatablePropertyStorage {
    private(set) var nodes: WeakSet<ViewNode> = []
    var propertyName: String = ""

    @MainActor
    func update() {
        nodes.forEach {
            if $0.shouldNotifyAboutChanges {
                print("\(type(of: $0.content)): \(propertyName) changed.")
            }

            $0.invalidateContent()
        }
    }

    @MainActor
    func registerNodeToUpdate(_ viewNode: ViewNode) {
        nodes.insert(viewNode)
        viewNode.storages.insert(self)
    }
}
