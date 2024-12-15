//
//  CubeMesh.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 03.12.2024.
//

import Math

public struct CubeShape: GeometryShape {
    public let size: Vector3

    public init(size: Vector3 = .one) {
        self.size = size
    }

    public func meshDescriptor() -> MeshDescriptor {
        let halfSize = Vector3(x: size.x / 2.0, y: size.y / 2.0, z: size.z / 2.0)

        // Create the MeshResource from the vertex and index buffers
        var mesh = MeshDescriptor(name: "Cube")
        mesh.primitiveTopology = .triangleList
        mesh.indicies = [
            0, 1, 2, 0, 2, 3, // front face
            4, 5, 6, 4, 6, 7, // back face
            0, 1, 5, 0, 5, 4, // bottom face
            2, 3, 7, 2, 7, 6, // top face
            0, 3, 7, 0, 7, 4, // left face
            1, 2, 6, 1, 6, 5  // right face
        ]
        mesh.positions = [
            Vector3(-halfSize.x, -halfSize.y, -halfSize.z), // 0
            Vector3( halfSize.x, -halfSize.y, -halfSize.z), // 1
            Vector3( halfSize.x,  halfSize.y, -halfSize.z), // 2
            Vector3(-halfSize.x,  halfSize.y, -halfSize.z), // 3
            Vector3(-halfSize.x, -halfSize.y,  halfSize.z), // 4
            Vector3( halfSize.x, -halfSize.y,  halfSize.z), // 5
            Vector3( halfSize.x,  halfSize.y,  halfSize.z), // 6
            Vector3(-halfSize.x,  halfSize.y,  halfSize.z)  // 7
        ]
        mesh.normals = [
            Vector3( 0,  0, -1), // front face
            Vector3( 0,  0,  1), // back face
            Vector3( 0, -1,  0), // bottom face
            Vector3( 0,  1,  0), // top face
            Vector3(-1,  0,  0), // left face
            Vector3( 1,  0,  0)  // right face
        ]
        mesh.textureCoordinates = [
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), // front face
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), // back face
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), // bottom face
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), // top face
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), // left face
            Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)  // right face
        ]

        return mesh
    }
}

extension Mesh {
    public static func generateBox(size: Vector3 = .one) -> Mesh {
        return .generate(from: CubeShape(size: size))
    }
}
