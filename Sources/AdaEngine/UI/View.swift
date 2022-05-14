//
//  View.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

import Math

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
    
    // FIXME:
    // [x] - Ortho projection for each view instead of root
    // [ ] - Blending mode (cuz alpha doesn't work)
    // [ ] - z layers
    // [ ] - texturing the views
    // [ ] - draw lines
    // [ ] - draw rectangles
    // [ ] - create transperent API for 2D rendering
    
    open func draw(in rect: Rect) {
        RenderEngine2D.shared.setFillColor(self.backgroundColor)
        RenderEngine2D.shared.drawQuad(origin: rect.origin, size: rect.size)
        
        for subview in self.subviews {
            subview.draw()
        }
    }
    
    private var globalFrame: Rect {
        if let origin = self.superview?.frame.origin {
            let offset: Vector2 = [self.frame.origin.x + origin.x, self.frame.origin.y + origin.y]
            return Rect(origin: offset, size: self.frame.size)
        }
        
        return self.frame
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
