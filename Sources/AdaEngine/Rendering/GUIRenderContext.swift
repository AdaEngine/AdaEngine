//
//  GUIRenderContext.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

import Math

/// Special object to render user interface on the screen
/// Context use orthogonal projection
final public class GUIRenderContext {
    
    private let engine: RenderEngine2D
    
    private var fillColor: Color = .clear
    private var strokeColor: Color = .black
    
    private var currentTransform = Transform3D.identity
    
    public init(engine: RenderEngine2D = .shared) {
        self.engine = engine
    }
    
    public func concatenate(_ transform: Transform3D) {
        self.currentTransform = self.currentTransform * transform
    }
    
    public func setCurrentTransform(_ transform: Transform3D) {
        self.currentTransform = transform
    }
    
    private var screenMatrix: Transform3D = .identity
    
    public func beginDraw(in rect: Rect) {
        let size = rect.size
        
        let view = Transform3D.orthogonal(
            left: 0,
            right: size.width,
            top: 0,
            bottom: -size.height,
            zNear: -1,
            zFar: 1
        )
        
        self.screenMatrix = view
        
        self.engine.beginContext(for: view)
    }
    
    public func setZIndex(_ index: Int) {
        self.engine.setZIndex(index)
    }
    
    public func setFillColor(_ color: Color) {
        self.fillColor = color
    }
    
    public func setStrokeColor(_ color: Color) {
        self.strokeColor = color
    }
    
    public func setXformTransform(_ transform: Transform2D) {
        self.currentTransform = self.makeCanvasTransform3D(from: transform)
    }
    
    public func setDebugName(_ name: String) {
        self.engine.setDebugName(name)
    }
    
    /// Paints the area contained within the provided rectangle, using the fill color in the current graphics state.
    public func fillRect(_ rect: Rect) {
        let transform = self.makeCanvasTransform3D(from: rect)
        self.engine.drawQuad(transform: self.currentTransform * transform, color: self.fillColor)
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func fillEllipse(in rect: Rect) {
        let transform = self.makeCanvasTransform3D(from: rect)
        self.engine.drawCircle(transform: self.currentTransform * transform, thickness: 0, fade: 0.005, color: self.fillColor)
    }
    
    public func commitDraw() {
        RenderEngine2D.shared.commitContext()
        
        self.clear()
    }
    
    // MARK: - Private
    
    private func clear() {
        self.fillColor = .clear
        self.strokeColor = .black
        self.currentTransform = .identity
        
        self.screenMatrix = .identity
    }
}

extension GUIRenderContext {
    func makeCanvasTransform3D(from transform: Transform2D) -> Transform3D {
        
        let origin = transform.xFormOrigin
        let size = transform.xFormSize
        
        return Transform3D(
            [size.x, 0, 0, 0],
            [0, size.y, 0, 0],
            [0, 0, 1, 0],
            [origin.x, origin.y, 0, 1]
        )
    }
    
    func makeCanvasTransform3D(from rect: Rect) -> Transform3D {
        let origin = rect.origin
        let size = rect.size
        
        if size.width < 0 || size.height < 0 {
            return .identity
        }
        
        return Transform3D(
            [size.width, 0, 0, 0],
            [0, size.height, 0, 0 ],
            [0, 0, 1.0, 0.0],
            [size.width / 2 + origin.x, -size.height / 2 - origin.y, 0, 1]
        )
    }
}
