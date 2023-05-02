//
//  iOSWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

#if os(iOS)
import UIKit

// swiftlint:disable:next type_name
final class iOSWindowManager: WindowManager {
    
    override func createWindow(for window: Window) {
        
        let screen = UIScreen.main
        let frame = screen.bounds.toEngineRect
        
        // Register view in engine
        
        let gameViewController = _GameViewController(window: window.id, frame: screen.bounds)
        try? RenderEngine.shared.createWindow(
            window.id,
            for: gameViewController.renderView,
            size: frame.size
        )
        
        let systemWindow = _AdaUIWindow(frame: screen.bounds)
        systemWindow.rootViewController = gameViewController
        systemWindow.backgroundColor = .black
        
        let pointerInteraction = UIPointerInteraction(delegate: systemWindow)
        systemWindow.addInteraction(pointerInteraction)
        systemWindow.pointerInteraction = pointerInteraction
        
        window.systemWindow = systemWindow
        window.minSize = frame.size
        
        super.createWindow(for: window)
    }
    
    // - TODO: (Vlad) I'm not really sure, that we should make window unfocused
    override func showWindow(_ window: Window, isFocused: Bool) {
        guard let uiWindow = window.systemWindow as? UIWindow else {
            fatalError("System window not exist.")
        }
        
        uiWindow.makeKeyAndVisible()
        
        window.windowDidAppear()
        
        self.setActiveWindow(window)
    }
    
    override func setWindowMode(_ window: Window, mode: Window.Mode) {
        guard let uiWindow = window.systemWindow as? UIWindow else {
            fatalError("System window not exist.")
        }
        
        print("Method doesn't implemented", #function)
    }
    
    override func closeWindow(_ window: Window) {
        guard let nsWindow = window.systemWindow as? UIWindow else {
            fatalError("System window not exist.")
        }

        self.removeWindow(window, setActiveAnotherIfNeeded: true)
        
        nsWindow.isHidden = true
        nsWindow.windowScene = nil
    }
    
    override func resizeWindow(_ window: Window, size: Size) {
        print("Method doesn't implemented", #function)
    }
    
    override func setMinimumSize(_ size: Size, for window: Window) {
        print("Method doesn't implemented", #function)
    }
    
    private(set) var currentShape: Input.CursorShape = .arrow
    private(set) var mouseMode: Input.MouseMode = .visible
    
    override func updateCursor() {
        guard let window = self.activeWindow?.systemWindow as? _AdaUIWindow else {
            return
        }
        
        // Causes the interaction to update the pointer in response to an event.
        window.pointerInteraction?.invalidate()
    }
    
    override func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotspot: Vector2) {
        
    }
    
    override func setCursorShape(_ shape: Input.CursorShape) {
        self.currentShape = shape
        
        self.updateCursor()
    }
    
    override func getMouseMode() -> Input.MouseMode {
        return self.mouseMode
    }
    
    override func setMouseMode(_ mode: Input.MouseMode) {
        self.mouseMode = mode
        
        self.updateCursor()
    }
    
    override func getCursorShape() -> Input.CursorShape {
        return self.currentShape
    }
    
    func findWindow(for nsWindow: UIWindow) -> Window? {
        return self.windows.first {
            ($0.systemWindow as? UIWindow) === nsWindow
        }
    }
}

final class _AdaUIWindow: UIWindow, SystemWindow, UIPointerInteractionDelegate {
    
    public var title: String = ""
    
    public var size: Size {
        get {
            return self.frame.size.toEngineSize
        }
        set {
            self.frame.size = CGSize(
                width: CGFloat(newValue.width),
                height: CGFloat(newValue.height)
            )
        }
    }
    
    public var position: Point {
        get {
            return self.frame.origin.toEnginePoint
        }
        set {
            self.frame.origin = CGPoint(
                x: CGFloat(newValue.x),
                y: CGFloat(newValue.y)
            )
        }
    }
    
    weak var pointerInteraction: UIPointerInteraction?
    
    // MARK: - UIPointerInteractionDelegate
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        
        if Input.getMouseMode() == .hidden {
            return UIPointerStyle.hidden()
        }
        
        var style: UIPointerStyle
        
        let cursorShape = Input.getCurrentCursorShape()
        
        switch cursorShape {
        case .iBeam:
            style = UIPointerStyle.hidden()
        default:
            if #available(iOS 15.0, *) {
                style = UIPointerStyle.system()
            } else {
                // Fallback on earlier versions
                style = UIPointerStyle.hidden()
            }
        }

        return style
    }
}

final class _GameViewController: UIViewController {
    
    var renderView: MetalView
    
    init(window: Window.ID, frame: CGRect) {
        self.renderView = MetalView(windowId: window, frame: frame)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalErrorMethodNotImplemented()
    }
    
    override func loadView() {
        self.view = self.renderView
    }
    
}

#endif
