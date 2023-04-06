//
//  CollisionCastQueryType.swift
//  
//
//  Created by v.prusakov on 4/5/23.
//

public enum CollisionCastQueryType {
    
    /// Report one hit
    case first
    
    /// Report all hits sorted in ascending order by distance from the cast origin.
    case all
}
