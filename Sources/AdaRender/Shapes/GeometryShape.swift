//
//  GeometryShape.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/30/23.
//

/// An interface that describe shape and can create mesh descriptor.
public protocol GeometryShape {
    func meshDescriptors() -> [MeshDescriptor]
}

public extension Mesh {
    /// Create a mesh resource from a shape.
    static func generate(from shape: GeometryShape, renderDevice: RenderDevice) -> Mesh {
        return self.generate(from: shape.meshDescriptors(), renderDevice: renderDevice)
    }
}
