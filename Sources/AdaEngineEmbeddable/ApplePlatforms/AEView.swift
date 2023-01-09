//
// Created by v.prusakov on 12/25/22.
//

#if canImport(MetalKit)
import MetalKit
import AdaEngine

/// The view for rendering AdaEngine scenes and views.
/// You can insert this view in your application and just pass scene or view to constructor.
/// This view will perfectly fit for any sizes.
public final class AEView: MetalView {
    
    /// Contains view where all render happens.
    /// You can grab information about all views.
    public let engineWindow: Window
    
    /// Create AEView with game scene.
    public convenience init(scene: Scene, frame: CGRect) {
        let sceneView = SceneView(scene: scene, frame: frame.toEngineRect)
        self.init(view: sceneView, frame: frame)
    }
    
    /// Create AEView with AdaEngine.View.
    public init(view: View, frame: CGRect) {
        let rect = frame.toEngineRect
        
        /// We should avoid multiple instancing of this object
        if Application.shared == nil {
            _ = try! AppleApplication(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
        }
        
        let window = Window(frame: rect)
        window.addSubview(view)
        
        self.engineWindow = window
        
        super.init(windowId: window.id, frame: frame)
        
        self.delegate = self
        
        do {
            // Register view in the engine.
            try RenderEngine.shared.createWindow(window.id, for: self, size: rect.size)
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }

    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // We should destroy renderable view to avoid unpredictable behaviour.
        try! RenderEngine.shared.destroyWindow(self.engineWindow.id)
    }
}

// MARK: - MTKViewDelegate

extension AEView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            self.engineWindow.frame.size = size.toEngineSize
            try RenderEngine.shared.resizeWindow(self.engineWindow.id, newSize: size.toEngineSize)
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }
    
    public func draw(in view: MTKView) {
        do {
            try GameLoop.current.iterate()
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }
}

#endif
