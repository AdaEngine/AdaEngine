//
//  Window.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

/// The base class describes the window in the system.
/// Each window instance can be presented on the screen.
/// The window holds a `SceneManager` instance to manage the game scene, but you can also use UI kit instead.
/// - Tag: AdaEngine.Window
open class Window: View {
    
    public typealias ID = RID
    
    // TODO: (Vlad) Maybe, we should use unique ID without RID
    /// Identifier using to register window in the render engine.
    /// We use this id to start drawing.
    public var id: ID = RID()
    
    // FIXME: (Vlad) Shouldn't be there
    let renderer2D = RenderEngine2D()
    
    public var title: String {
        get { self.systemWindow?.title ?? "" }
        set { self.systemWindow?.title = newValue }
    }
    
    internal var systemWindow: SystemWindow?
    
    public var windowManager: WindowManager {
        return Application.shared.windowManager
    }
    
    /// Flag indicates that window can draw itself content in method [draw(with:)](x-source-tag://AdaEngine.Window.drawWithContext).
    open var canDraw: Bool = false
    
    private var _minSize: Size = .zero
    public var minSize: Size {
        get {
            return _minSize
        }
        set {
            self.windowManager.setMinimumSize(newValue, for: self)
            self._minSize = newValue
        }
    }
    
    public internal(set) var isFullscreen: Bool = false
    
    // Flag indicates that window is active.
    public internal(set) var isActive: Bool = false
    
    public convenience override init() {
        self.init(frame: .zero)
    }
    
    public required init(frame: Rect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.windowManager.createWindow(for: self)
    }
    
    open func showWindow(makeFocused flag: Bool) {
        self.windowManager.showWindow(self, isFocused: flag)
    }
    
    open func close() {
        self.windowManager.closeWindow(self)
    }
    
    // MARK: - Public Methods
    
    open func setWindowMode(_ mode: Window.Mode) {
        self.windowManager.setWindowMode(self, mode: mode)
    }
    
    // MARK: - Lifecycle
    
    /// Called one when window ready to use.
    open func windowDidReady() {
        
    }
    
    /// Called each time when window did appear on screen.
    open func windowDidAppear() {
        
    }
    
    /// Called once when window did disapper from screen.
    open func windowDidDisappear() {
        
    }
    
    open func windowDidBecameActive() {
        
    }
    
    open func windowDidResignActive() {
        
    }
    
    /// Called when user did press `Close` button
    open func windowShouldClose() -> Bool {
        return true
    }
    
    // MARK: - Overriding
    
    override func frameDidChange() {
        self.windowManager.resizeWindow(self, size: self.frame.size)
        
        super.frameDidChange()
    }
    
    /// - Tag: AdaEngine.Window.drawWithContext
    override func draw(with context: GUIRenderContext) {
        super.draw(with: context)
    }
    
    /// - Tag: AdaEngine.Window.drawInRectWithContext
    open override func draw(in rect: Rect, with context: GUIRenderContext) {
        super.draw(in: rect, with: context)
    }
    
    public override func addSubview(_ view: View) {
        
        if let anotherWindow = view.window {
            if anotherWindow === self {
                assertionFailure("View already added on this window.")
            } else {
                fatalError("You cannot add view as subview, because view holded by another window.")
            }
        }
        
        view.window = self
        super.addSubview(view)
    }
    
    public override func removeSubview(_ view: View) {
        if let window = view.window, window !== self {
            fatalError("You cant remove view from another window instance.")
        }
        
        view.window = nil
        super.removeSubview(view)
    }
}

public extension Window {
    enum Mode: UInt64 {
        case windowed
        case fullscreen
    }
    
    static let defaultMinimumSize = Size(width: 800, height: 600)
}
