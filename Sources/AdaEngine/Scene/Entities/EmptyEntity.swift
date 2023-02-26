//
//  EmptyEntity.swift
//  
//
//  Created by v.prusakov on 2/19/23.
//

public final class EmptyEntity: Entity {
    public override init(name: String = "Entity") {
        super.init(name: name)
        self.components.removeAll()
    }
}
