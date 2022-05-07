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
            self.materials?.first
        }
        
        set {
            self.materials = [newValue].compactMap { $0 }
        }
    }
    
    public var materials: [Material]? {
        didSet {
            self.updateDrawableMaterials()
        }
    }
    
    public var mesh: Mesh? {
        didSet {
            self.updateDrawableSource()
        }
    }
    
    private var drawable: Drawable?
    
    public override func ready() {
        let drawable = RenderEngine.shared.makeDrawable()
        drawable.source = self.mesh.flatMap { .mesh($0) } ?? .empty
        drawable.materials = self.materials
        
        self.drawable = drawable
        
        RenderEngine.shared.setDrawableToQueue(drawable, layer: 0)
    }
    
    public override func destroy() {
        guard let drawable = self.drawable else { return }
        RenderEngine.shared.removeDrawableFromQueue(drawable)
    }
    
    // MARK: - Private
    
    func updateDrawableSource() {
        self.drawable?.source = self.mesh.flatMap { .mesh($0) } ?? .empty
    }
    
    func updateDrawableMaterials() {
        self.drawable?.materials = self.materials
    }

}
