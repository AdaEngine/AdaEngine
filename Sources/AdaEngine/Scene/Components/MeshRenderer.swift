//
//  MeshRenderer.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import SwiftUI

/// Component to render mesh on scene
public class MeshRenderer: Component {
    
    public var mesh: Mesh? {
        didSet {
            self.updateBuffers()
        }
    }
    
    private var buffer: RenderBuffer?
    
    public override func ready() {
        guard let renderEngine = RenderEngine.shared else {
            assert(false, "Can't get render engine")
            return
        }
        
        let length = MemoryLayout<Vector3>.size * (mesh?.vertexCount ?? 0)
        self.buffer = renderEngine.makeRenderBuffer(length: length)
    }
    
    public override func update(_ deltaTime: TimeInterval) {
        
    }
    
    // MARK: - Private methods
    
    private func updateBuffers() {
        
        if let mesh = self.mesh {
            let length = MemoryLayout<Vector3>.size * mesh.vertexCount
            self.buffer?.updateBuffer(mesh.verticies, length: length)
        }
    }
}
