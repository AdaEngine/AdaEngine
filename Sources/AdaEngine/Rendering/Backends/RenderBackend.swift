//
//  RenderBackend.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Math

struct Uniforms {
    let modelMatrix: Transform3D
    let viewMatrix: Transform3D
    let projectionMatrix: Transform3D
}

struct Vertex {
    let pos: Vector3
    let color: Vector4
}

public protocol RenderBackend: AnyObject {
    func createWindow(for view: RenderView, size: Vector2i) throws
    func resizeWindow(newSize: Vector2i) throws

    func beginFrame() throws
    func endFrame() throws
}
