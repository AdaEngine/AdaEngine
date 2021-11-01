//
//  MeshRenderer.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import SwiftUI

public class MeshRenderer: Component {
    
    public var mesh: Mesh?
    
    @RequiredComponent private var transform: Transform
    
    public override func update(_ deltaTime: TimeInterval) {
        let transform = self.transform
    }
}
