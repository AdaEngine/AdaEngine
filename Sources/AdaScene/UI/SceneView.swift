//
//  SceneView.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

import AdaUI
import AdaUtils
import Math

/// This view contains game scene and viewport for rendering.
@MainActor
public class SceneView: UIView {

    /// The scene manager that manage a scenes for this view.
    public let sceneManager: SceneManager
    
    /// A viewport that describe size and depth for rendering.
    
    public required init(frame: Rect) {
        self.sceneManager = SceneManager()
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    public convenience init(scene: Scene, frame: Rect) {
        self.init(frame: frame)
        self.sceneManager.presentScene(scene)
    }
    
    public override func frameDidChange() {
        super.frameDidChange()
    }

    public override func viewWillMove(to window: UIWindow?) {
        self.sceneManager.setWindow(window)
    }

    public override func update(_ deltaTime: TimeInterval) async {
        await self.sceneManager.update(deltaTime)
    }
}
