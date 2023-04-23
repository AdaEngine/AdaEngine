//
//  EmptyEntity.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

/// An entity that doesn't contains any component.
public final class EmptyEntity: Entity {
    public override init(name: String = "Entity") {
        super.init(name: name)
        self.components.removeAll()
    }
}
