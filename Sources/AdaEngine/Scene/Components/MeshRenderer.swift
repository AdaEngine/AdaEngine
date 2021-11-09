//
//  MeshRenderer.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

/// Component to render mesh on scene
public class MeshRenderer: Component {
    
    public var material: Material?
    
    public var mesh: Mesh? {
        didSet {
            self.updateDrawableSource()
        }
    }
    
    private var drawable: Drawable?
    
    public override func ready() {
        let drawable = RenderEngine.shared.makeDrawable()
        drawable.source = self.mesh.flatMap { .mesh($0) } ?? .empty
        drawable.material = BaseMaterial(diffuseColor: .gray, metalic: 0)
        self.drawable = drawable
        
        RenderEngine.shared.setDrawableToQueue(drawable)
    }
    
    public override func destroy() {
        guard let drawable = self.drawable else { return }
        RenderEngine.shared.removeDrawableFromQueue(drawable)
    }
    
    // MARK: - Private
    
    func updateDrawableSource() {
        self.drawable?.source = self.mesh.flatMap { .mesh($0) } ?? .empty
    }

}
