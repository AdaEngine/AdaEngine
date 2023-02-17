//
//  SceneView.swift
//  
//
//  Created by v.prusakov on 1/9/23.
//

public class SceneView: View {
    
    public let sceneManager: SceneManager
    
    public internal(set) var viewport: Viewport = Viewport()
    
    public override var window: Window? {
        didSet {
            self.sceneManager.setWindow(self.window)
        }
    }
    
    public required init(frame: Rect) {
        self.sceneManager = SceneManager()
        super.init(frame: frame)
        self.sceneManager.sceneView = self
    }
    
    public convenience init(scene: Scene, frame: Rect) {
        self.init(frame: frame)
        self.sceneManager.presentScene(scene)
    }
    
    override func frameDidChange() {
        super.frameDidChange()
        self.viewport.rect.size = self.frame.size
        
        self.sceneManager.setViewport(self.viewport)
    }
    
    public override func update(_ deltaTime: TimeInterval) {
        self.sceneManager.update(deltaTime)
    }
    
}
