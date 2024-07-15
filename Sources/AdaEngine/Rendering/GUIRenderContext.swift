//
//  UIGraphicsContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

import Math

// TODO: Clip Mask
// TODO: Layers

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
public struct UIGraphicsContext {

    /// Window Identifier related presented window.
    private let camera: Camera
    private var transform: Transform3D = .identity
    private(set) var currentDrawContext: Renderer2D.DrawContext?
    
    public internal(set) var environment: EnvironmentValues = EnvironmentValues()

    @MainActor
    @preconcurrency
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
    
    internal mutating func beginDraw(in size: Size, scaleFactor: Float) {
        let view = Transform3D.orthographic(
            left: 0,
            right: size.width / scaleFactor,
            top: 0,
            bottom: -size.height / scaleFactor,
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

    public mutating func concatenate(_ transform: Transform3D) {
        self.transform = transform * self.transform
    }

    public mutating func translateBy(x: Float, y: Float) {
        let translationMatrix = Transform3D(translation: [x, y, 0])
        self.transform = translationMatrix * self.transform
    }
    
    public mutating func scaleBy(x: Float, y: Float) {
        let scaleMatrix = Transform3D(translation: [x, y, 1])
        self.transform = scaleMatrix * self.transform
    }

    public mutating func rotate(by angle: Angle) {
        self.transform = self.transform.rotate(angle: angle, axis: .up)
    }

    // MARK: - Drawing

    /// Paints the area contained within the provided rectangle, using the passed color.
    public func drawRect(_ rect: Rect, color: Color) {
        self.drawRect(rect, texture: nil, color: color)
    }
    
    /// Paints the area contained within the provided rectangle, using the passed color and texture.
    public func drawRect(_ rect: Rect, texture: Texture2D? = nil, color: Color) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawQuad(transform: transform, texture: texture, color: color)
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func drawEllipse(in rect: Rect, color: Color) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawCircle(transform: transform, thickness: 1, fade: 0.005, color: color)
    }

    public func drawText(in rect: Rect, from textLayout: TextLayoutManager) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawText(textLayout, transform: transform)
    }

    func drawGlyph(_ glyph: Glyph, at point: Point) {
        let rect = Rect(
            origin: Point(x: point.x, y: point.y),
            size: glyph.size
        )
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawGlyph(glyph, transform: transform)
    }

    public mutating func commitDraw() {
        self.currentDrawContext?.commitContext()
    }
    
    // MARK: - Private
    
    private mutating func clear() {
        self.transform = .identity
    }
}

extension UIGraphicsContext {
    
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
            translation: [self.midX, -self.midY, 0], 
            rotation: .identity,
            scale: [self.size.width, self.size.height, 1]
        )
    }
}
