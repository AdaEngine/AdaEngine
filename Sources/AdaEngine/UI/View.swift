//
//  View.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

import Math
import AppKit

// TODO:
// [ ] - Ortho projection for each view instead of root
// [ ] - Add transforms for drawing (translation/rotation/scale)
// [ ] - Blending mode (cuz alpha doesn't work)
// [ ] - z layers
// [ ] - texturing the views
// [ ] - draw lines
// [ ] - draw rectangles
// [ ] - create transperent API for 2D rendering
// [ ] - Interaction (hit testing)
// [ ] - Scaling problem (hit testing)
open class View {
    
    // MARK: - Public Fields -
    
    /// Contains size and position coordinates relative to parent local coordinates
    open var frame: Rect {
        get {
            return self.data.frame
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
    
    /// Affine matrix to apply any transformation to current view
    public var affineTransform: Transform2D {
        get {
            return Transform2D(transform: self.transform3D)
        }
        
        set {
            self.transform3D = Transform3D(newValue)
        }
    }
    
    public var transform3D: Transform3D = .identity
    
    // MARK: - Private Fields -
    
    private var _localTransform: Transform3D = .identity
    
    private var data: Data = Data()
    
    public convenience init(frame: Rect) {
        self.init()
        self.frame = frame
        self.bounds.size = frame.size
    }

    public init() { }
    
    // MARK: - Private
    
    private func setFrame(_ frame: Rect) {
        
        self._localTransform = Transform3D(
            translation: [frame.origin.x, frame.origin.y, 0],
            rotation: .identity,
            scale: [frame.size.width, frame.size.height, 1]
        )
        
        self.bounds.size = frame.size
        self.data.frame = frame
        
        self.frameDidChange()
    }
    
    private func frameDidChange() {
        self.data.cacheWorldTransform = self.worldTransform
        
        for view in subviews {
            view.frameDidChange()
        }
    }
    
}

// MARK: - Interaction

extension View {
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
        let transform = Transform2D(transform: self.data.cacheWorldTransform * view.data.cacheWorldTransform).inverse
        return point.applying(transform)
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
}

// MARK: - Rendering

extension View {
    
    private var worldTransform: Transform3D {
        if let superView = self.superview {
            return superView.worldTransform * self._localTransform
        }
        
        return self._localTransform
    }
    
    open func draw(in rect: Rect, with context: GUIRenderContext) {
        guard self.isVisible else { return }
        
        context.setFillColor(self.backgroundColor)
        context.fillRect(rect)

        for subview in self.subviews {
            subview.draw(with: context)
        }
    }

    internal func draw(with context: GUIRenderContext) {
        context.setTransform(self.data.cacheWorldTransform)
        context.setZIndex(self.zIndex)
        self.draw(in: self.bounds, with: context)
    }
}

private extension View {
    struct Data {
        var cacheWorldTransform: Transform3D = .identity
        var frame: Rect = .zero
    }
}

// MARK: - View Hierarchy

public extension View {
    
    func addSubview(_ view: View) {
        if self === view {
            fatalError("Can't add self as subview")
        }
        
        if view.superview != nil {
            fatalError("Can't add view if view attached to another view")
        }
        
        self.subviews.append(view)
        view.superview = self
    }
    
    func removeFromSuperview() {
        self.superview?.removeSubview(self)
    }
    
    func removeSubview(_ view: View) {
        guard let index = self.subviews.firstIndex(where: { $0 === view }) else { return }
        let deletedView = self.subviews.remove(at: index)
        deletedView.superview = nil
    }
}
