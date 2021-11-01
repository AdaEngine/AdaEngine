//
//  Transform.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//


public class Transform: Component {
    
    public var matrix: Transform3D
    
    override init() {
        self.matrix = .identity
    }
    
}
