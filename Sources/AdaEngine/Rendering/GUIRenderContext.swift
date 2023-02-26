//
//  GUIRenderContext.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

import Math

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
final public class GUIRenderContext {
    
    private let engine: Renderer2D
    
    private var fillColor: Color = .clear
    private var strokeColor: Color = .black
    
    private var currentTransform = Transform3D.identity
    
    /// Window Identifier related presented window.
    private unowned let window: Window
    
    public init(window: Window, engine: Renderer2D) {
        self.window = window
        self.engine = engine
    }
    
    public func concatenate(_ transform: Transform3D) {
        self.currentTransform = self.currentTransform * transform
    }
    
    public func setCurrentTransform(_ transform: Transform3D) {
        self.currentTransform = transform
    }
    
    var view: Transform3D = .identity
    private var screenRect: Rect = .zero
    
    private var currentDrawContext: Renderer2D.DrawContext?
    
    public func beginDraw(in screenRect: Rect) {
        let size = screenRect.size
        
//        let view = Transform3D.orthographic(
//            left: 0,
//            right: size.width,
//            top: 0,
//            bottom: -size.height,
//            zNear: -1,
//            zFar: 1
//        )
        
        self.screenRect = screenRect
        self.view = .identity//view
        
        self.currentDrawContext = self.engine.beginContext(for: self.window, viewTransform: view)
    }
    
    public func setFillColor(_ color: Color) {
        self.fillColor = color
    }
    
    public func setStrokeColor(_ color: Color) {
        self.strokeColor = color
    }
    
    public func setTransform(_ transform: Transform2D) {
        self.currentTransform = self.makeCanvasTransform3D(from: transform)
    }
    
    public func setDebugName(_ name: String) {
        self.currentDrawContext?.setDebugName(name)
    }
    
    /// Paints the area contained within the provided rectangle, using the fill color in the current graphics state.
    public func fillRect(_ rect: Rect) {
        let transform = self.makeCanvasTransform3D(from: rect)
        self.currentDrawContext?.drawQuad(transform: transform, color: self.fillColor)
    }
    
    public func fillRect(_ xform: Transform3D) {
        self.currentDrawContext?.drawQuad(transform: xform, color: self.fillColor)
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func fillEllipse(in rect: Rect) {
        let transform = self.makeCanvasTransform3D(from: rect)
        self.currentDrawContext?.drawCircle(transform: self.currentTransform * transform, thickness: 1, fade: 0.005, color: self.fillColor)
    }
    
    public func commitDraw() {
        self.currentDrawContext?.commitContext()
        
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
        // swiftlint:disable:next identifier_name
        let m = affineTransform
        return Transform3D(
            [m[0, 0], m[0, 1], 0, m[0, 2]],
            [m[1, 0], m[1, 1], 0, m[1, 2]],
            [0,       0,       1, 0      ],
            [m[2, 0], -m[2, 1], 0, m[2, 2]]
        )
    }
    
    func makeCanvasTransform3D(from rect: Rect) -> Transform3D {
        let origin = rect.origin
        let size = rect.size
        let screenSize = self.screenRect.size
        
        if size.width < 0 || size.height < 0 {
            return .identity
        }

        return Transform3D(
            [size.width / screenSize.width, 0, 0, 0],
            [0, size.height / screenSize.height, 0, 0 ],
            [0, 0, 1.0, 0.0],
            [origin.x, -origin.y, 0, 1]
        )
    }
}

// model -> view -> projection
// quad -> .identity -> ortho
// quad -> ortho

// position = ortho * quad
