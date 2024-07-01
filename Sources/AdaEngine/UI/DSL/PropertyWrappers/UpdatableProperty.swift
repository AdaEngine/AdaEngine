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
    var storage: UpdatablePropertyStorage { get }
}

class UpdatablePropertyStorage {
    var nodes: WeakSet<ViewNode> = []
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

    func registerNodeToUpdate(_ ViewNode: ViewNode) {
        nodes.insert(ViewNode)
    }
}
