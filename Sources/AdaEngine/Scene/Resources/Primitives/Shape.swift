//
//  Shape.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/30/23.
//

/// An interface that describe shape and can create mesh descriptor.
public protocol Shape {
    func meshDescriptor() -> MeshDescriptor
}
