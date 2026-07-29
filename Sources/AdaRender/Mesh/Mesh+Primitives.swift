//
//  Mesh+Primitives.swift
//  AdaEngine
//

import Math

public extension Mesh {
    /// Generates a UV sphere suitable for lit and textured 3D materials.
    static func generateSphere(
        radius: Float = 0.5,
        segments: Int = 32,
        rings: Int = 20,
        renderDevice: RenderDevice
    ) -> Mesh {
        precondition(radius > 0, "Sphere radius must be greater than zero")
        precondition(segments >= 3, "A sphere requires at least three segments")
        precondition(rings >= 2, "A sphere requires at least two rings")

        var descriptor = MeshDescriptor(name: "Sphere")
        var positions: [Vector3] = []
        var normals: [Vector3] = []
        var textureCoordinates: [Vector2] = []
        var indices: [UInt32] = []

        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let theta = v * .pi
            let y = Math.cos(theta)
            let ringRadius = Math.sin(theta)
            for segment in 0...segments {
                let u = Float(segment) / Float(segments)
                let phi = u * .pi * 2
                let normal = Vector3(
                    x: ringRadius * Math.cos(phi),
                    y: y,
                    z: ringRadius * Math.sin(phi)
                )
                positions.append(normal * radius)
                normals.append(normal)
                textureCoordinates.append([u, v])
            }
        }

        let stride = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * stride + segment)
                let next = UInt32((ring + 1) * stride + segment)
                indices.append(contentsOf: [
                    current, current + 1, next,
                    current + 1, next + 1, next
                ])
            }
        }

        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(textureCoordinates)
        descriptor.indicies = indices
        return Mesh.generate(from: [descriptor], renderDevice: renderDevice)
    }
}
