//
//  SceneView.swift
//  
//
//  Created by v.prusakov on 1/9/23.
//

public class SceneView: View {
    
    public let sceneManager: SceneManager
//    private let viewport: Viewport
    
    public override var window: Window? {
        didSet {
//            self.viewport.window = window?.id
            self.sceneManager.viewport = self.window?.viewport
        }
    }
    
    public required init(frame: Rect) {
        self.sceneManager = SceneManager()
//        self.viewport = Viewport(frame: frame)
//        self.sceneManager.viewport = self.viewport
        super.init(frame: frame)
    }
    
    public convenience init(scene: Scene, frame: Rect) {
        self.init(frame: frame)
        self.sceneManager.presentScene(scene)
    }
    
    override func frameDidChange() {
        super.frameDidChange()
        
//        self.viewport.size = self.frame.size
//        self.viewport.position = self.frame.origin
    }
    
    public override func update(_ deltaTime: TimeInterval) {
        self.sceneManager.update(deltaTime)
    }
    
}
