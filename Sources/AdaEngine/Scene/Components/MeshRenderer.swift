//
//  MeshRenderer.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

/// Component to render mesh on scene
public class MeshRenderer: ScriptComponent {
    
    public var material: Material? {
        get {
            self.materials.first
        }
        
        set {
            self.materials = [newValue].compactMap { $0 }
        }
    }
    
//    @Export - currently not supported for protocols Material
    public var materials: [Material] = [] {
        didSet {
            self.updateDrawableMaterials()
        }
    }
    
    @Export
    public var mesh: Mesh? {
        didSet {
            self.updateDrawableSource()
        }
    }
    
    public override func ready() {

    }
    
    public override func destroy() {
        
    }
    
    // MARK: - Private
    
    func updateDrawableSource() {
        
    }
    
    func updateDrawableMaterials() {
        
    }

}
