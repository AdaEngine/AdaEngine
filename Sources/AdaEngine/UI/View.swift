//
//  View.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/11/22.
//

import Math

// - TODO: (Vlad) Ortho projection for each view instead of root
// - TODO: (Vlad) Add transforms for drawing (translation/rotation/scale)
// - TODO: (Vlad) Blending mode (cuz alpha doesn't work)
// - TODO: (Vlad) z layers
// - TODO: (Vlad) texturing the views
// - TODO: (Vlad) draw lines
// - TODO: (Vlad) draw rectangles
// - TODO: (Vlad) create transperent API for 2D rendering
// - TODO: (Vlad) Interaction (hit testing)
// - TODO: (Vlad) Scaling problem (hit testing)
// - TODO: (Vlad) Cropping

/// An object that manages the content for a rectangular area on the screen.
///
/// Views are the fundamental building blocks of your app’s user interface, and the ``View`` class defines the behaviors that are common to all views.
///
/// - Warning: Under development and currently doesn't work as expected.
@MainActor
open class View {

    // MARK: - Public Fields -

    /// Contains size and position coordinates relative to parent local coordinates
    open var frame: Rect {
        didSet {
            self.setFrame(self.frame)
        }
    }

    /// Contains size and position relative to self local coordinates.
    open var bounds: Rect = .zero

    /// Contains link to parent super view
    public private(set) weak var superview: View?

    public private(set) var subviews: [View] = []

    open var backgroundColor: Color = Color.white

    open var isInteractionEnabled: Bool = true

    open var isHidden: Bool = false

    open var zIndex: Int = 0

    public internal(set) weak var window: Window?

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
        self.affineTransform = Transform2D(scale: Vector2(frame.size.width, frame.size.height)) * Transform2D(translation: frame.origin)
        self.bounds.size = frame.size

        self.frameDidChange()
    }

    func frameDidChange() {
        for view in subviews {
            view.frameDidChange()
        }
    }

    // MARK: Rendering

    open func draw(in rect: Rect, with context: GUIRenderContext) {
        if self.isHidden {
            return
        }

        context.setFillColor(self.backgroundColor)
        context.fillRect(rect)

        for subview in self.subviews {
            subview.draw(with: context)
        }
    }

    internal func draw(with context: GUIRenderContext) {
        self.draw(in: self.bounds, with: context)
    }

    private var worldTransform: Transform2D {
        if let superView = self.superview {
            return superView.affineTransform * self.affineTransform
        }

        return self.affineTransform
    }

    // MARK: - Life cycle

    /// - Parameter superView: Return view instance if view attached to superview or nil if view deattached from superview.
    /// Also superview can be [Window](x-source-tag://AdaEngine.Window) instance.
    open func viewDidMove(to superView: View?) {

    }

    // MARK: - Interaction

    open func hitTest(_ point: Point, with event: InputEvent) -> View? {
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

    public func convert(_ point: Point, to view: View?) -> Point {
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

    public func convert(_ point: Point, from view: View?) -> Point {
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

        let view = self.hitTest(position, with: event)
        view?.backgroundColor = .mint
    }

    // MARK: - View Hierarchy

    open func addSubview(_ view: View) {
        if self === view {
            fatalError("Can't add self as subview")
        }

        if view.superview != nil {
            fatalError("Can't add view if view attached to another view")
        }

        self.subviews.append(view)
        view.superview = self

        view.viewDidMove(to: self)
    }

    open func removeFromSuperview() {
        self.superview?.removeSubview(self)
    }

    open func removeSubview(_ view: View) {
        guard let index = self.subviews.firstIndex(where: { $0 === view }) else { return }
        let deletedView = self.subviews.remove(at: index)
        deletedView.superview = nil
        view.viewDidMove(to: nil)
    }

    /// Called each frame
    open func update(_ deltaTime: TimeInterval) async {
        for subview in self.subviews {
            await subview.update(deltaTime)
        }
    }
}

// frame is a size and position view in scene, relative to parent.
// If we set position or size, we should calculate new local coordinates relative to parent.
// and also we should set that transform to the render context. If we want calculate position relative to screen space or another view space, we should calculate world transform matrix.
