//
//  GUIRenderContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

import Math

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
@MainActor
final public class GUIRenderContext {
    
    private var strokeColor: Color = .black
    
    /// Window Identifier related presented window.
    private let camera: Camera
    
    init(window: UIWindow) {
        let camera = Camera(window: window.id)
        camera.isActive = true
        camera.projection = .orthographic
        
        self.camera = camera
    }
    
    init(texture: RenderTexture) {
        let camera = Camera(renderTarget: texture)
        camera.isActive = true
        camera.projection = .orthographic
        
        self.camera = camera
    }
    
    public func multiply(_ transform: Transform3D) {
        self.currentTransform = self.currentTransform * transform
    }
    
    var stack: [Transform3D] = [.identity]
    
    var currentTransform: Transform3D {
        get {
            return stack[self.stack.count - 1]
        }
        
        set {
            stack[self.stack.count - 1] = newValue
        }
    }
    
    private var screenRect: Rect = .zero
    
    private var currentDrawContext: Renderer2D.DrawContext?
    
    internal func beginDraw(in rect: Rect) {
        let view = Transform3D.orthographic(
            left: 0,
            right: screenRect.width,
            top: 0,
            bottom: screenRect.height,
            zNear: -1,
            zFar: 1
        )

        self.currentDrawContext = Renderer2D.beginDrawContext(
            for: self.camera,
            viewUniform: GlobalViewUniform(
                viewProjectionMatrix: view
            )
        )
    }
    
    public func saveContext() {
        self.stack.append(.identity)
    }
    
    public func restoreContext() {
        self.stack.removeLast()
    }
    
    public func setStrokeColor(_ color: Color) {
        self.strokeColor = color
    }
    
    public func translateBy(x: Float, y: Float) {
        let translationMatrix = Transform3D(translation: [x, y, 0])
        self.currentTransform = translationMatrix * currentTransform
    }
    
    public func concat(_ transform: Transform3D) {
        self.currentTransform = transform * currentTransform
    }
    
    func scaleBy(x: Float, y: Float) {
        let scaleMatrix = Transform3D(translation: [x, y, 1])
        self.currentTransform = scaleMatrix * self.currentTransform
    }
    
    /// Paints the area contained within the provided rectangle, using the passed color.
    public func drawRect(_ rect: Rect, color: Color) {
        self.drawRect(rect, texture: nil, color: color)
    }
    
    /// Paints the area contained within the provided rectangle, using the passed color and texture.
    public func drawRect(_ rect: Rect, texture: Texture2D? = nil, color: Color) {
        let modelMatrix = self.currentTransform
        let transform = rect.toTransform3D
        self.currentDrawContext?.drawQuad(transform: transform, texture: texture, color: color)
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func drawEllipse(in rect: Rect, color: Color) {
        let transform = rect.toTransform3D
        self.currentDrawContext?.drawCircle(transform: transform, thickness: 1, fade: 0.005, color: color)
    }
    
    public func commitDraw() {
        self.currentDrawContext?.commitContext()
        
        self.clear()
    }
    
    // MARK: - Private
    
    private func clear() {
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
}

extension Rect {
    var toTransform3D: Transform3D {
        Transform3D(
            translation: [self.minX, self.minY, 0], 
            rotation: .identity,
            scale: [self.size.width, self.size.height, 1]
        )
    }
}

// model -> view -> projection
// quad -> .identity -> ortho
// quad -> ortho

// position = ortho * quad

class UILayer {
    var texture: Texture2D?
}
