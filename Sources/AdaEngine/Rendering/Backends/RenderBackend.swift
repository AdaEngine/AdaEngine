//
//  RenderBackend.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Math

public protocol RenderBackend: AnyObject {
    func createWindow(for view: RenderView, size: Vector2i) throws
    func resizeWindow(newSize: Vector2i) throws
    func beginFrame() throws
    func endFrame() throws
}
