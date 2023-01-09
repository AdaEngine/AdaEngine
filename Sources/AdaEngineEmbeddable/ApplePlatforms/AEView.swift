//
// Created by v.prusakov on 12/25/22.
//

#if canImport(MetalKit)
import MetalKit
import AdaEngine

public class AEView: MetalView {
    
    private let engineWindow: Window
    private unowned let sceneView: SceneView
    private let application: Application
    
    public init(scene: Scene, frame: CGRect) {
        
        let rect = frame.toEngineRect
        
        self.application = try! AppleApplication(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
        
        let window = Window(frame: rect)
        let sceneView = SceneView(scene: scene, frame: rect)
        window.addSubview(sceneView)
        self.sceneView = sceneView
        
        self.engineWindow = window
        
        super.init(windowId: window.id, frame: frame)
        
        self.delegate = self
        
        do {
            /// Register view in engine
            try RenderEngine.shared.createWindow(window.id, for: self, size: rect.size)
        } catch {
            print("[AEView Error]", error.localizedDescription)
        }
    }

    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
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

class AppleApplication: Application {
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
        
        
        self.windowManager = AppleWindowManager()
    }
}

class AppleWindowManager: WindowManager {
    override init() {
        
    }
    
    override func resizeWindow(_ window: Window, size: Size) {
        
    }
    
    override func createWindow(for window: Window) {
        super.createWindow(for: window)
    }
    
    override func setWindowMode(_ window: Window, mode: Window.Mode) {
        
    }
    
    override func closeWindow(_ window: Window) {
        
    }
    
    override func showWindow(_ window: Window, isFocused: Bool) {
        
    }
}

#endif
