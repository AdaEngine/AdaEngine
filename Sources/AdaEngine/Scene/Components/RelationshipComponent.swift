//
//  RelationshipComponent.swift
//  
//
//  Created by v.prusakov on 1/20/23.
//

import Collections

struct RelationshipComponent: Component {
    var parent: Entity.ID?
    var children: OrderedSet<Entity.ID> = []
}
