//
// Created by v.prusakov on 12/25/22.
//

#if canImport(MetalKit)
import MetalKit
@_spi(Internal) import AdaEngine

/// The view for rendering AdaEngine scenes and views.
/// You can insert this view in your application and just pass scene or view to constructor.
/// This view will perfectly fit for any sizes.
@MainActor
public final class AEView: MetalView {
    
    /// Contains view where all render happens.
    /// You can grab information about all views.
    public let engineWindow: AdaEngine.UIWindow
    
    /// Create AEView with game scene.
    public convenience init(scene: Scene, frame: CGRect) {
        let sceneView = SceneView(scene: scene, frame: frame.toEngineRect)
        self.init(view: sceneView, frame: frame)
    }
    
    /// Create AEView with AdaEngine.View.
    public init(view: UIView, frame: CGRect) {
        let rect = frame.toEngineRect
        
        /// We should avoid multiple instancing of this object
        if Application.shared == nil {
            let app = try! AppleApplication(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
            Application.setApplication(app)
        }
        
        let window = AdaEngine.UIWindow(frame: rect)
        window.addSubview(view)
        
        let appContext = AppContext(_EmbeddableApp(window: window))
        self.engineWindow = window
        
        super.init(windowId: window.id, frame: frame)
        
        Application.shared.appleWindowManager.nativeView = self
        self.delegate = self
        
        Task { [appContext] in
            do {
                try await appContext.setup()
                try RenderEngine.shared.createWindow(window.id, for: self, size: rect.size.toSizeInt())
                try AudioServer.shared.start()
            } catch {
                print("[AEView Error]", error.localizedDescription)
            }
        }
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        do {
            try AudioServer.shared.stop()
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }
}

// MARK: - MTKViewDelegate

extension AEView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            self.engineWindow.frame.size = size.toEngineSize
            try RenderEngine.shared.resizeWindow(self.engineWindow.id, newSize: size.toEngineSize.toSizeInt())
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }
    
    public func draw(in view: MTKView) {
        Task {
            do {
                try await MainLoop.current.iterate()
            } catch {
                print("[AEView Error]", error.localizedDescription)
            }
        }
    }
}

private struct _EmbeddableApp: AdaEngine.App {
    let window: UIWindow
    
    var scene: some AppScene {
        GUIAppScene(window: {
            window
        })
    }
}

private extension Application {
    var appleWindowManager: AppleWindowManager {
        self.windowManager as! AppleWindowManager
    }
}

#endif
