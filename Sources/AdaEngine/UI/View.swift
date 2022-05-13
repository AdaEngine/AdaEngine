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
    
    open func draw(in rect: Rect) {
//        RenderEngine2D.shared.setOrhoTransform(for: rect)
        RenderEngine2D.shared.setFillColor(self.backgroundColor)
        RenderEngine2D.shared.drawQuad(rect)
        
        for subview in subviews {
            subview.draw()
        }
    }
    
    open func draw() {
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
