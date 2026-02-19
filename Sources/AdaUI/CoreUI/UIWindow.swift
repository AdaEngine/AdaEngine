//
//  Window.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

import AdaInput
import AdaUtils
import Math

/// The base class describes the window in the system.
/// Each window instance can be presented on the screen.
/// - Tag: AdaEngine.Window
@MainActor
open class UIWindow: UIView {

    public typealias ID = RID
    
    // TODO: (Vlad) Maybe, we should use unique ID without RID
    /// Identifier using to register window in the render engine.
    /// We use this id to start drawing.
    nonisolated public let id: ID = RID()
    
    public var title: String {
        get { self.systemWindow?.title ?? "" }
        set { self.systemWindow?.title = newValue }
    }

    public var windowManager: UIWindowManager {
        UIWindowManager.shared
    }
    
    @_spi(Internal) public var systemWindow: SystemWindow?
    internal let eventManager = EventManager()

    /// Flag indicates that window can draw itself content in method ``UIView/draw(in:with:)``.
    open var canDraw: Bool = true

    private var dirtyRect: Rect?

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
    
    public var isFullscreen: Bool = false

    public var screen: Screen? {
        return windowManager.getScreen(for: self)
    }
    
    /// Flag indicates that window is active.
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

    open func setWindowMode(_ mode: UIWindow.Mode) {
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

    func markDirty(_ rect: Rect) {
        if let dirtyRect {
            self.dirtyRect = dirtyRect.union(rect)
        } else {
            self.dirtyRect = rect
        }
    }

    func consumeDirtyRect() -> Rect? {
        defer {
            dirtyRect = nil
        }
        return dirtyRect
    }

    func sendEvent(_ event: any InputEvent) {
        guard self.canRespondToAction(event) else {
            return
        }

        let responder = self.findFirstResponder(for: event) ?? self.defaultResponder(for: event) ?? self
        responder.onEvent(event)
    }

    private func defaultResponder(for event: any InputEvent) -> UIView? {
        switch event {
        case is KeyEvent, is TextInputEvent:
            // Keyboard/text events have no hit-test point, route to topmost
            // view container so it can forward input to the focused node.
            for subview in self.zSortedChildren.reversed() where subview.canRespondToAction(event) {
                return subview
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Overriding
    
    open override func frameDidChange() {
        self.windowManager.resizeWindow(self, size: self.frame.size)
        super.frameDidChange()
    }
    
    public override func addSubview(_ view: UIView) {
        if view is UIWindow {
            fatalError("You cannot add window as subview to another window")
        }
        
        if let anotherWindow = view.window {
            if anotherWindow === self {
                assertionFailure("View already added on this window.")
            } else {
                fatalError("You cannot add view as subview, because view holded by another window.")
            }
        }

        super.addSubview(view)
    }
    
    public override func removeSubview(_ view: UIView) {
        if let window = view.window, window !== self {
            fatalError("You cant remove view from another window instance.")
        }
        
        super.removeSubview(view)
    }
}

public extension UIWindow {
    enum Mode: UInt64, Sendable {
        case windowed
        case fullscreen
    }
    
    nonisolated static let defaultMinimumSize = Size(width: 800, height: 600)
}
