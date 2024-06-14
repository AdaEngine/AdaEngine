//
//  View.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/11/22.
//

import Math

// - TODO: (Vlad) Add transforms for drawing (translation/rotation/scale)
// - TODO: (Vlad) Blending mode (cuz alpha doesn't work)
// - TODO: (Vlad) texturing the views
// - TODO: (Vlad) draw lines
// - TODO: (Vlad) draw rectangles
// - TODO: (Vlad) create transperent API for 2D rendering
// - TODO: (Vlad) Interaction (hit testing)
// - TODO: (Vlad) Cropping

/// An object that manages the content for a rectangular area on the screen.
///
/// Views are the fundamental building blocks of your app’s user interface, and the ``View`` class defines the behaviors that are common to all views.
///
/// - Warning: Under development and currently doesn't work as expected.
@MainActor
open class UIView {

    // MARK: - Public Fields -

    /// Contains size and position coordinates relative to parent local coordinates
    open var frame: Rect {
        didSet {
            self.setFrame(self.frame)
        }
    }
    
    var needsResortZPositionForChildren = false
    var _zSortedChildren: [UIView] = []
    var zSortedChildren: [UIView] {
        if needsResortZPositionForChildren {
            _zSortedChildren = self.subviews.sorted(by: { $0.zIndex > $1.zIndex })
            needsResortZPositionForChildren = false
        }
        
        return _zSortedChildren
    }

    /// Contains size and position relative to self local coordinates.
    open var bounds: Rect = .zero

    /// Contains link to parent super view
    public private(set) weak var superview: UIView?

    public private(set) var subviews: [UIView] = []

    open var isInteractionEnabled: Bool = true

    open var isHidden: Bool = false

    open var zIndex: Int = 0 {
        didSet {
            self.superview?.needsResortZPositionForChildren = true
        }
    }
    
    private var needsLayout = true
    
    public var backgroundColor: Color = .white

    public var window: UIWindow? {
        var superview = self.superview
        
        while superview != nil {
            if let window = superview as? UIWindow {
                return window
            }
            
            superview = superview?.superview
        }
        
        return nil
    }

    /// Affine matrix to apply any transformation to current view
    public var affineTransform: Transform2D = .identity

    // MARK: - Private Fields -

    public required init(frame: Rect) {
        self.frame = frame
        self.bounds.size = frame.size
    }

    public init() {
        self.frame = .zero
    }

    // MARK: - Private

    func setFrame(_ frame: Rect) {
        self.bounds.size = frame.size

        self.frameDidChange()
        
        self.setNeedsLayout()
    }

    func frameDidChange() {
        for view in subviews {
            view.frameDidChange()
        }
    }

    // MARK: Rendering
    
    open func draw(in rect: Rect, with context: GUIRenderContext) { }
    
    // TODO: 
    /// Internal method for drawing
    internal func draw(with context: GUIRenderContext) {
        if self.isHidden {
            return
        }
        
        context.saveContext()
        
        if affineTransform != .identity {
            context.multiply(Transform3D(from: affineTransform))
        }
        
        context.translateBy(x: self.frame.midX, y: -self.frame.midY)
        
        /// Draw background
        context.drawRect(self.bounds, color: self.backgroundColor)
        
        self.draw(in: self.bounds, with: context)

        for subview in self.zSortedChildren {
            subview.draw(with: context)
        }
        
        context.restoreContext()
    }

    private var worldTransform: Transform2D {
        if let superView = self.superview {
            return superView.affineTransform * self.affineTransform
        }

        return self.affineTransform
    }
    
    // MARK: - Life Cycle
    
    public func setNeedsLayout() {
        self.needsLayout = true
    }
    
    public func layoutIfNeeded() {
        if needsLayout {
            self.layoutSubviews()
            self.needsLayout = false
        }
    }
    
    open func layoutSubviews() {
        for subview in subviews {
            subview.layoutSubviews()
        }
    }

    // MARK: - Life cycle

    /// - Parameter superView: Return view instance if view attached to superview or nil if view deattached from superview.
    /// Also superview can be [Window](x-source-tag://AdaEngine.Window) instance.
    open func viewDidMove(to superView: UIView?) { }

    // MARK: - Interaction

    open func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        guard self.isInteractionEnabled && !self.isHidden else {
            return nil
        }

        if !self.point(inside: point, with: event) {
            return nil
        }

        if self.subviews.isEmpty {
            return self
        }

        for subview in self.subviews.reversed() {
            let newPoint = subview.convert(point, from: self)
            if let view = subview.hitTest(newPoint, with: event) {
                return view
            }
        }

        return self
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    open func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.bounds.contains(point: point)
    }

    public func convert(_ point: Point, to view: UIView?) -> Point {
        guard let view, view !== self else {
            return point
        }

        if view.superview === self {
            return (point - view.frame.origin).applying(self.affineTransform.inverse) + view.bounds.origin
        } else if let superview, superview === view {
            return (point - bounds.origin).applying(self.affineTransform) + frame.origin
        }

        let currentWorldTransform = self.worldTransform.position
        let viewWorldTransform = self.worldTransform.position

        return point - (viewWorldTransform - currentWorldTransform)
    }

    public func convert(_ point: Point, from view: UIView?) -> Point {
        return view?.convert(point, to: self) ?? point
    }

    func sendEvent(_ event: InputEvent) {
        switch event {
        case let event as MouseEvent:
            self.handleMouseEvent(event)
        case let event as TouchEvent:
            self.handleTouchEvent(event)
        case let event as KeyEvent:
            self.handleKeyEvent(event)
        default:
            return
        }
    }

    internal func handleKeyEvent(_ event: KeyEvent) {

    }

    internal func handleMouseEvent(_ event: MouseEvent) {
        // if user click on view, we should handle it
        if event.button == .left || event.button == .right {
            self.handleClick(event.mousePosition, with: event)
        }

    }

    internal func handleTouchEvent(_ event: TouchEvent) {

    }

    private func handleClick(_ position: Point, with event: InputEvent) {
        guard self.isInteractionEnabled else { return }
    }

    // MARK: - View Hierarchy

    open func addSubview(_ view: UIView) {
        if self === view {
            fatalError("Can't add self as subview")
        }

        if view.superview != nil {
            fatalError("Can't add view if view attached to another view")
        }

        self.subviews.append(view)
        view.superview = self

        view.viewDidMove(to: self)
        
        self.needsResortZPositionForChildren = true
        
        self.setNeedsLayout()
    }

    open func removeFromSuperview() {
        self.superview?.removeSubview(self)
    }

    open func removeSubview(_ view: UIView) {
        guard let index = self.subviews.firstIndex(where: { $0 === view }) else { return }
        let deletedView = self.subviews.remove(at: index)
        deletedView.superview = nil
        view.viewDidMove(to: nil)
        
        self.needsResortZPositionForChildren = true
    }

    /// Called each frame
    open func update(_ deltaTime: TimeInterval) async {
        self.layoutIfNeeded()
        
        for subview in self.subviews {
            await subview.update(deltaTime)
        }
    }
}

// frame is a size and position view in scene, relative to parent.
// If we set position or size, we should calculate new local coordinates relative to parent.
// and also we should set that transform to the render context. If we want calculate position relative to screen space or another view space, we should calculate world transform matrix.
