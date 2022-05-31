//
//  GUIRenderContext.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

import Math
import GLKit

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
final public class GUIRenderContext {
    
    private let engine: RenderEngine2D
    
    private var fillColor: Color = .clear
    private var strokeColor: Color = .black
    
    private var currentTransform = Transform3D.identity
    
    /// Window Identifier related presented window.
    private let window: Window.ID
    
    public init(window: Window.ID, engine: RenderEngine2D = .shared) {
        self.window = window
        self.engine = engine
    }
    
    public func concatenate(_ transform: Transform3D) {
        self.currentTransform = self.currentTransform * transform
    }
    
    public func setCurrentTransform(_ transform: Transform3D) {
        self.currentTransform = transform
    }
    
    public func beginDraw(in rect: Rect) {
        let size = rect.size
        
        let view = Transform3D.orthogonal(
            left: 0,
            right: size.width / 2,
            top: 0,
            bottom: -size.height / 2,
            zNear: -1,
            zFar: 1
        )
        
        self.engine.beginContext(for: self.window, viewTransform: view)
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
    
    public func setTransform(_ transform: Transform3D) {
        self.currentTransform = transform
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
    }
}

extension GUIRenderContext {
    func makeCanvasTransform3D(from affineTransform: Transform2D) -> Transform3D {
        return Transform3D(affineTransform)
    }
    
    func makeCanvasTransform3D(from rect: Rect) -> Transform3D {
        let origin = rect.origin
        let size = rect.size
        
        if size.width < 0 || size.height < 0 {
            return .identity
        }
        
        return Transform3D(
            translation: [origin.x, origin.y, 0],
            rotation: .identity,
            scale: [size.width, size.height, 1]
        )
//
//        return Transform3D(
//            [size.width, 0, 0, 0],
//            [0, size.height, 0, 0 ],
//            [0, 0, 1.0, 0.0],
//            [size.width / 2 + origin.x, -size.height / 2 - origin.y, 0, 1]
//        )
    }
}
