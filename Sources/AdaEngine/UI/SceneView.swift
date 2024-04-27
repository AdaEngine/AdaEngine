//
//  SceneView.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

/// This view contains game scene and viewport for rendering.
public class SceneView: View {
    
    /// The scene manager that manage a scenes for this view.
    public let sceneManager: SceneManager
    
    /// A viewport that describe size and depth for rendering.
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

    public override func update(_ deltaTime: TimeInterval) async {
        await self.sceneManager.update(deltaTime)
    }
    
}
