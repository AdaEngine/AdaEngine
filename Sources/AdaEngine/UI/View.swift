//
//  View.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

import Math

// TODO:
// [ ] - Ortho projection for each view instead of root
// [ ] - Add transforms for drawing (translation/rotation/scale)
// [x] - Blending mode (cuz alpha doesn't work)
// [ ] - z layers
// [ ] - texturing the views
// [ ] - draw lines
// [x] - draw rectangles
// [ ] - create transperent API for 2D rendering
// [ ] - Interaction (hit testing)
// [ ] - Scaling problem (hit testing)
// [ ] - Cropping

/// - Tag: AdaEngine.View
open class View {
    
    // MARK: - Public Fields -
    
    /// Contains size and position coordinates relative to parent local coordinates
    open var frame: Rect {
        get {
            return self._data.frame
        }
        set {
            self.setFrame(newValue)
        }
    }
    
    /// Contains size and position relative to self local coordinates.
    open var bounds: Rect = .zero
    
    /// Contains link to parent super view
    public private(set) weak var superview: View?
    
    public private(set) var subviews: [View] = []
    
    open var backgroundColor: Color = Color.white
    
    open var isInteractionEnabled: Bool = true
    
    open var isVisible: Bool = true
    
    open var zIndex: Int = 0
    
    public internal(set) weak var window: Window?
    
    /// Affine matrix to apply any transformation to current view
    public var affineTransform: Transform2D = .identity
    
    // MARK: - Private Fields -
    
    private var _localTransform: Transform2D = .identity
    
    private var _data: ViewData = ViewData()
    
    public required init(frame: Rect) {
        self.frame = frame
        self.bounds.size = frame.size
    }

    public init() {
        self.frame = .zero
    }
    
    // MARK: - Private
    
    func setFrame(_ frame: Rect) {
        
        self._localTransform = self._localTransform
            .scaledBy(x: frame.size.width, y: frame.size.height)
            .translatedBy(x: frame.origin.x, y: frame.origin.y)// * affineTransform
        
        self.bounds.size = frame.size
        self._data.frame = frame
        
        self.frameDidChange()
    }
    
    func frameDidChange() {
        self._data.cacheWorldTransform = self.worldTransform
        
        for view in subviews {
            view.frameDidChange()
        }
    }
    
    // MARK: Rendering
    
    open func draw(in rect: Rect, with context: GUIRenderContext) {
        guard self.isVisible else { return }
        
        context.setFillColor(self.backgroundColor)
        context.fillRect(rect)

        for subview in self.subviews {
            subview.draw(with: context)
        }
    }

    internal func draw(with context: GUIRenderContext) {
        context.setTransform(self._data.cacheWorldTransform)
        self.draw(in: self.bounds, with: context)
    }
    
    private var worldTransform: Transform2D {
        if let superView = self.superview {
            return superView.worldTransform * self._localTransform
        }
        
        return self._localTransform
    }
    
    // MARK: - Life cycle
    
    /// - Parameter superView: Return view instance if view attached to superview or nil if view deattached from superview.
    /// Also superview can be [Window](x-source-tag://AdaEngine.Window) instance.
    open func viewDidMove(to superView: View?) {
        
    }
    
    // MARK: - Interaction
    
    open func hitTest(_ point: Point, with event: Event) -> View? {
        guard self.isInteractionEnabled && self.isVisible else {
            return nil
        }
        
        if !self.point(inside: point, with: event) {
            return nil
        }
        
        if self.subviews.isEmpty {
            return self
        }
        
        for subview in self.subviews {
            let newPoint = subview.convert(point, from: self)
            if let view = subview.hitTest(newPoint, with: event) {
                return view
            }
        }
        
        return self
    }
    
    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    open func point(inside point: Point, with event: Event) -> Bool {
        return self.bounds.contains(point: point)
    }
    
    func convert(_ point: Point, from view: View) -> Point {
//        let transform = Transform2D(transform: self.data.cacheWorldTransform * view.data.cacheWorldTransform).inverse
//        return point.applying(transform)
        return .zero
    }
    
    func sendEvent(_ event: Event) {
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
    
    private func handleClick(_ position: Point, with event: Event) {
        guard self.isInteractionEnabled else { return }
//        let position = Point(x: 80, y: 26)
        print("Mouse", position.x, position.y)
        
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
}

private extension View {
    struct ViewData {
        var cacheWorldTransform: Transform2D = .identity
        var frame: Rect = .zero
    }
}

// frame is a size and position view in scene, relative to parent.
// If we set position or size, we should calculate new local coordinates relative to parent.
// and also we should set that transform to the render context. If we want calculate position relative to screen space or another view space, we should calculate world transform matrix.
