//
//  UpdatableProperty.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
public protocol UpdatableProperty {
    func update()
}

@MainActor
protocol PropertyStoragable {
    var _storage: UpdatablePropertyStorage { get }
}

@MainActor
class UpdatablePropertyStorage {
    var propertyName: String = ""
    weak var widgetNode: WidgetNode?
    
    func update() {
        self.widgetNode?.invalidateContent()
    }
}
