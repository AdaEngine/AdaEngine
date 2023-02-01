//
//  ModelComponent.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

public struct ModelComponent {
    
    public var mesh: Mesh
    
    public init(mesh: Mesh) {
        self.mesh = mesh
    }
    
}

/// Component to render mesh on scene
//public class MeshRenderer: ScriptComponent {
//    
//    public var material: Material? {
//        get {
//            self.materials.first
//        }
//        
//        set {
//            self.materials = [newValue].compactMap { $0 }
//        }
//    }
//    
////    @Export - currently not supported for protocols Material
//    public var materials: [Material] = [] {
//        didSet {
//            self.updateDrawableMaterials()
//        }
//    }
//    
////    @Export - currently not supported for resources
//    public var mesh: Mesh? {
//        didSet {
//            self.updateDrawableSource()
//        }
//    }
//    
//    public override func ready() {
//
//    }
//    
//    public override func destroy() {
//        
//    }
//    
//    // MARK: - Private
//    
//    func updateDrawableSource() {
//        
//    }
//    
//    func updateDrawableMaterials() {
//        
//    }
//
//}
