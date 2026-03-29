//
//  AppleEmbeddedWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

#if IOS || TVOS
import UIKit
import AdaInput
@_spi(Internal) import AdaUI
import AdaRender
import AdaUtils
import Math

// swiftlint:disable:next type_name
final class AppleEmbeddedWindowManager: UIWindowManager {
    private let screenManager: any ScreenManager

    init(screenManager: any ScreenManager) {
        self.screenManager = screenManager
    }

    override func createWindow(for window: AdaUI.UIWindow) {
        let scene = activeWindowScene()
        let screen = scene?.screen ?? UIScreen.main
        let sceneBounds = scene?.coordinateSpace.bounds ?? screen.bounds
        let frame = sceneBounds.toEngineRect
        
        // Register view in engine
        
        let gameViewController = _GameViewController(window: window.id, frame: sceneBounds)


        // Setup windowManager reference for input handling
        gameViewController.renderView.windowManager = self
        gameViewController.renderView.setupMouseTracking()
        
        let systemWindow: _AdaUIWindow
        if let scene {
            systemWindow = _AdaUIWindow(
                windowScene: scene,
                frame: sceneBounds,
                windowManager: self
            )
        } else {
            systemWindow = _AdaUIWindow(frame: sceneBounds, windowManager: self)
        }
        systemWindow.rootViewController = gameViewController
        systemWindow.backgroundColor = .black
        
        let pointerInteraction = UIPointerInteraction(delegate: systemWindow)
        systemWindow.addInteraction(pointerInteraction)
        systemWindow.pointerInteraction = pointerInteraction
        
        window.systemWindow = systemWindow
        window.minSize = frame.size

        unsafe try? RenderEngine.shared.createWindow(
            window.id,
            for: gameViewController.renderView,
            size: frame.size.toSizeInt()
        )

        super.createWindow(for: window)
    }
    
    // - TODO: (Vlad) I'm not really sure, that we should make window unfocused
    override func showWindow(_ window: AdaUI.UIWindow, isFocused: Bool) {
        guard let uiWindow = window.systemWindow as? UIKit.UIWindow else {
            fatalError("System window not exist.")
        }

        attachWindowToSceneIfNeeded(uiWindow)
        uiWindow.makeKeyAndVisible()

        if let appDelegate = UIApplication.shared.delegate as? AppleEmbeddedAppDelegate {
            appDelegate.window = uiWindow
        }

        window.windowDidAppear()

        self.setActiveWindow(window)
    }
    
    override func setWindowMode(_ window: AdaUI.UIWindow, mode: AdaUI.UIWindow.Mode) {
        window.isFullscreen = mode == .fullscreen
    }
    
    override func closeWindow(_ window: AdaUI.UIWindow) {
        guard let nsWindow = window.systemWindow as? UIKit.UIWindow else {
            fatalError("System window not exist.")
        }

        self.removeWindow(window, setActiveAnotherIfNeeded: true)
        
        nsWindow.isHidden = true
        nsWindow.windowScene = nil
    }

    override func getScreen(for window: AdaUI.UIWindow) -> Screen? {
        guard let screen = (window.systemWindow as? UIKit.UIWindow)?.screen else {
            return nil
        }
        
        return Screen.init(systemScreen: screen, screenManager: screenManager)
    }

    override func resizeWindow(_ window: AdaUI.UIWindow, size: Math.Size) {
        guard let uiWindow = window.systemWindow as? UIKit.UIWindow else {
            return
        }

        let currentOrigin = uiWindow.frame.origin
        let newFrame = CGRect(origin: currentOrigin, size: size.toCGSize)

        uiWindow.frame = newFrame
        uiWindow.rootViewController?.view.frame = CGRect(origin: .zero, size: size.toCGSize)
    }
    
    override func setMinimumSize(_ size: Size, for window: AdaUI.UIWindow) {
        guard let uiWindow = window.systemWindow as? UIKit.UIWindow else {
            return
        }

        let currentSize = uiWindow.frame.size.toEngineSize
        let clampedSize = Size(
            width: max(currentSize.width, size.width),
            height: max(currentSize.height, size.height)
        )

        if clampedSize != currentSize {
            resizeWindow(window, size: clampedSize)
        }
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
    
    override func setCursorImage(
        for shape: Input.CursorShape,
        texture: Texture2D?,
        hotspot: Vector2
    ) {

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
    
    func findWindow(for nsWindow: UIKit.UIWindow) -> AdaUI.UIWindow? {
        return self.windows.first {
            ($0.systemWindow as? UIKit.UIWindow) === nsWindow
        }
    }

    private func attachWindowToSceneIfNeeded(_ window: UIKit.UIWindow) {
        guard #available(iOS 13.0, tvOS 13.0, *), window.windowScene == nil else {
            return
        }

        let scene = activeWindowScene()

        guard let scene else {
            return
        }

        window.windowScene = scene
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController?.view.frame = scene.coordinateSpace.bounds
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first {
                $0.activationState == .foregroundActive
                    || $0.activationState == .foregroundInactive
            }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
    }
}

final class _AdaUIWindow: UIKit.UIWindow, SystemWindow, UIPointerInteractionDelegate {
    
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
    private var windowManager: AppleEmbeddedWindowManager?

    init(frame: CGRect, windowManager: AppleEmbeddedWindowManager) {
        self.windowManager = windowManager
        super.init(frame: frame)
    }

    @available(iOS 13.0, tvOS 13.0, *)
    init(windowScene: UIWindowScene, frame: CGRect, windowManager: AppleEmbeddedWindowManager) {
        self.windowManager = windowManager
        super.init(windowScene: windowScene)
        self.frame = frame
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UIPointerInteractionDelegate
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        
        if windowManager?.getMouseMode() == .hidden {
            return UIPointerStyle.hidden()
        }
        
        var style: UIPointerStyle
        
        let cursorShape = windowManager?.getCursorShape() ?? .arrow
        
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

    init(window: AdaUI.UIWindow.ID, frame: CGRect) {
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
