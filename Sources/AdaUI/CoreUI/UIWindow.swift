//
//  Window.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

import AdaECS
import AdaInput
import AdaUtils
import Foundation
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

    public var configuration: Configuration
    
    public var title: String {
        get { self.systemWindow?.title ?? "" }
        set { self.systemWindow?.title = newValue }
    }

    public var windowManager: UIWindowManager {
        UIWindowManager.shared
    }
    
    @_spi(Internal) public var systemWindow: SystemWindow?
    @_spi(Internal) public var runtimeCameraEntity: Entity?
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

    public convenience init(configuration: Configuration) {
        self.init(frame: configuration.frame, configuration: configuration)
    }
    
    public required init(frame: Rect) {
        self.configuration = Configuration(frame: frame)
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.windowManager.createWindow(for: self)
    }

    init(frame: Rect, configuration: Configuration) {
        self.configuration = configuration
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
        case is KeyEvent, is TextInputEvent, is KeyboardEvent:
            if let focusedResponder = self.findFocusedInputResponderInSubviews(for: event) {
                return focusedResponder
            }

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

    private func findFocusedInputResponderInSubviews(for event: any InputEvent) -> UIView? {
        for subview in self.zSortedChildren.reversed() {
            if let focusedResponder = subview.findFocusedInputResponder(for: event) {
                return focusedResponder
            }
        }

        return nil
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

private extension UIView {
    func findFocusedInputResponder(for event: any InputEvent) -> UIView? {
        for subview in self.zSortedChildren.reversed() {
            if let focusedResponder = subview.findFocusedInputResponder(for: event) {
                return focusedResponder
            }
        }

        guard
            self.canRespondToAction(event),
            let focusedContainer = self as? any FocusedInputContainer,
            focusedContainer.hasFocusedInputNode
        else {
            return nil
        }

        return self
    }
}

public extension UIWindow {
    struct Configuration: Sendable {
        public var title: String?
        public var frame: Rect
        public var minimumSize: Size
        public var mode: Mode
        public var chrome: Chrome
        public var titleBar: TitleBar
        public var background: Background
        public var level: Level
        public var collectionBehavior: CollectionBehavior
        public var showsImmediately: Bool
        public var makeKey: Bool

        public init(
            title: String? = nil,
            frame: Rect = .zero,
            minimumSize: Size = UIWindow.defaultMinimumSize,
            mode: Mode = .windowed,
            chrome: Chrome = .standard,
            titleBar: TitleBar = .standard,
            background: Background = .opaque(.black),
            level: Level = .normal,
            collectionBehavior: CollectionBehavior = .standard,
            showsImmediately: Bool = true,
            makeKey: Bool = true
        ) {
            self.title = title
            self.frame = frame
            self.minimumSize = minimumSize
            self.mode = mode
            self.chrome = chrome
            self.titleBar = titleBar
            self.background = background
            self.level = level
            self.collectionBehavior = collectionBehavior
            self.showsImmediately = showsImmediately
            self.makeKey = makeKey
        }
    }

    enum Chrome: Sendable, Equatable {
        case standard
        case borderless
    }

    struct TitleBar: Sendable, Equatable {
        public var background: TitleBarBackground
        public var reservesSafeArea: Bool
        public var dragRegionHeight: Float?
        public var trafficLightOffset: Point?

        public static let standard = TitleBar(background: .system, reservesSafeArea: true, dragRegionHeight: nil, trafficLightOffset: nil)
        public static let transparent = TitleBar(background: .transparent, reservesSafeArea: true, dragRegionHeight: nil, trafficLightOffset: nil)
        public static let overlay = TitleBar(background: .transparent, reservesSafeArea: false, dragRegionHeight: 52, trafficLightOffset: nil)

        public init(
            background: TitleBarBackground,
            reservesSafeArea: Bool = true,
            dragRegionHeight: Float? = nil,
            trafficLightOffset: Point? = nil
        ) {
            self.background = background
            self.reservesSafeArea = reservesSafeArea
            self.dragRegionHeight = dragRegionHeight
            self.trafficLightOffset = trafficLightOffset
        }
    }

    enum TitleBarBackground: Sendable, Equatable {
        case system
        case transparent
    }

    enum Background: Sendable, Equatable {
        case opaque(Color)
        case transparent

        public var isTransparent: Bool {
            if case .transparent = self {
                return true
            }
            return false
        }
    }

    enum Level: Sendable {
        case normal
        case floating
        case statusBar
    }

    enum CollectionBehavior: Sendable {
        case standard
        case allSpacesStationary
    }

    enum Mode: UInt64, Sendable {
        case windowed
        case fullscreen
    }
    
    nonisolated static let defaultMinimumSize = Size(width: 800, height: 600)
}

public extension Notification.Name {
    static let adaEngineWindowDidMiniaturize = Notification.Name("AdaEngine.WindowDidMiniaturize")
    static let adaEngineWindowDidDeminiaturize = Notification.Name("AdaEngine.WindowDidDeminiaturize")
}
