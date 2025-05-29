//
//  EmptyEntity.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

/// An entity that doesn't contains any component.
/// By default Entity object contains Transform, Visibility and Child/Parent component,
/// but this entity is full empty
public final class EmptyEntity: Entity, @unchecked Sendable {
    public override init(name: String = "EmptyEntity") {
        super.init(name: name)
        self.components.removeAll()
    }
}
