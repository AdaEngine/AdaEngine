//
//  View.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

import Math


// TODO:
// [x] - Ortho projection for each view instead of root
// [ ] - Add transforms for drawing (translation/rotation/scale)
// [ ] - Blending mode (cuz alpha doesn't work)
// [ ] - z layers
// [ ] - texturing the views
// [ ] - draw lines
// [ ] - draw rectangles
// [ ] - create transperent API for 2D rendering
// [ ] - Interaction (hit testing)
open class View {
    
    open var frame: Rect = .zero
    
    public private(set) weak var superview: View?
    
    public private(set) var subviews: [View] = []
    
    open var backgroundColor: Color = Color.white
    
    var zIndex: Int = 0
    
    public var affineTransform: Transform2D {
        get {
            return self.transform3D.basis
        }
        
        set {
            self.transform3D = Transform3D(transform2D: newValue)
        }
    }
    
    public var transform3D: Transform3D = .identity
    
    public convenience init(frame: Rect) {
        self.init()
        self.frame = frame
    }
    
    public init() {
        
    }
    
    open var isInteractionEnabled: Bool = true
    open var isVisible: Bool = true
  
}

// MARK: - Interaction

extension View {
    open func hitTest(_ point: Point, with event: Event) -> View? {
        return nil
    }
    
    
    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    open func point(inside point: Point, with event: Event) -> Bool {
        if self.globalFrame.contains(point: point) {
            for subview in subviews {
                return subview.point(inside: point, with: event)
            }
        }
        
        return false
    }
    
    internal func handleKeyEvent(_ event: KeyEvent) {
        
    }
    
    internal func handleMouseEvent(_ event: MouseEvent) {
        print(event.mousePosition)
        
        // if user click on view, we should handle it
        if event.button == .left || event.button == .right {
            self.handleClick(event.mousePosition, with: event)
        }
        
    }
    
    internal func handleTouchEvent(_ event: TouchEvent) {
        
    }
    
    private func handleClick(_ position: Point, with event: Event) {
        guard self.isInteractionEnabled else { return }
        if self.point(inside: position, with: event) {
            self.hitTest(position, with: event)
        }
    }
}

// MARK: - Rendering

extension View {
    
    // Compute current position in world space
    private var globalFrame: Rect {
        if let origin = self.superview?.frame.origin {
            let offset: Vector2 = [self.frame.origin.x + origin.x, self.frame.origin.y + origin.y]
            return Rect(origin: offset, size: self.frame.size)
        }
        
        return self.frame
    }
    
    open func draw(in rect: Rect) {
        guard self.isVisible else { return }
        RenderEngine2D.shared.setFillColor(self.backgroundColor)
        RenderEngine2D.shared.drawQuad(origin: rect.origin, size: rect.size)
        
        for subview in self.subviews {
            subview.draw()
        }
    }

    internal func draw() {
        let globalOrigin = self.globalFrame.origin
        
        RenderEngine2D.shared.setCurrentTransform(
            Transform3D(
                translation: [globalOrigin.x , globalOrigin.y, Float(self.zIndex)]
            )
        )
        
        self.draw(in: self.frame)
    }
}

// MARK

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
