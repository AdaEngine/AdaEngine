//
//  UIGraphicsContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

import Math

// TODO: Clip Mask

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
@MainActor
public struct UIGraphicsContext {
    /// Window Identifier related presented window.
    private let camera: Camera

    /// Returns current transform.
    public private(set) var transform: Transform3D = .identity
    private(set) var currentDrawContext: Renderer2D.DrawContext?
    private var clipPath: Path?

    public var opacity: Float = 1

    /// Values passed for render context.
    public var environment: EnvironmentValues = EnvironmentValues()

    // Used for internal and debug values.
    @_spi(AdaEngineEditor) public var _environment: EnvironmentValues = EnvironmentValues()

    private var viewMatrix: Transform3D = .identity

    @MainActor init(window: UIWindow) {
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
            right: size.width * scaleFactor,
            top: 0,
            bottom: -size.height * scaleFactor,
            zNear: 0,
            zFar: 1000
        )
        self.viewMatrix = view

        do {
            self.currentDrawContext = try Renderer2D.beginDrawContext(
                for: self.camera,
                viewUniform: GlobalViewUniform(
                    viewProjectionMatrix: view
                )
            )
        } catch {
            print("[Error] \(error)")
        }
    }

    public mutating func concatenate(_ transform: Transform3D) {
        self.transform = transform * self.transform
    }

    public mutating func translateBy(x: Float, y: Float) {
        let translationMatrix = Transform3D(translation: [x, y, 0])
        self.transform = translationMatrix * self.transform
    }
    
    public mutating func scaleBy(x: Float, y: Float) {
        let scaleMatrix = Transform3D(scale: [x, y, 1])
        self.transform = scaleMatrix * self.transform
    }

    public mutating func rotate(by angle: Angle) {
        self.transform = Transform3D(quat: Quat(axis: Vector3(0, 0, 1), angle: angle.radians)) * self.transform
    }

    public mutating func clearTransform() {
        self.transform = .identity
    }

    // MARK: - Drawing

    /// Paints the area contained within the provided rectangle, using the passed color.
    public func drawRect(_ rect: Rect, color: Color) {
        self.drawRect(rect, texture: nil, color: applyOpacityIfNeeded(color))
    }

    /// Paints the area contained within the provided rectangle, using the passed color and texture.
    public func drawRect(_ rect: Rect, texture: Texture2D? = nil, color: Color) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawQuad(transform: transform, texture: texture, color: applyOpacityIfNeeded(color))
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func drawEllipse(in rect: Rect, color: Color) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawCircle(transform: transform, thickness: 1, fade: 0.005, color: applyOpacityIfNeeded(color))
    }

    public func drawLine(start: Vector2, end: Vector2, lineWidth: Float, color: Color) {
        let start = (transform * Vector4(start.x, start.y, 0, 1))
        let end = (transform * Vector4(end.x, end.y, 0, 1))

        self.currentDrawContext?.drawLine(start: start.xyz, end: end.xyz, lineWidth: lineWidth, color: applyOpacityIfNeeded(color))
    }

    private func applyOpacityIfNeeded(_ color: Color) -> Color {
        if color == .clear {
            return color
        }

        return color.opacity(self.opacity)
    }

    // MARK: - Text Drawing

    public func drawText(in rect: Rect, from textLayout: TextLayoutManager) {
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawText(textLayout, transform: transform)
    }

    public func draw(_ path: Path) {
        
    }

    public func draw(_ line: TextLine) {
        for run in line {
            self.draw(run)
        }
    }

    public func draw(_ run: TextRun) {
        for glyph in run {
            self.draw(glyph)
        }
    }

    public func draw(_ glyph: Glyph) {
        let rect = Rect(
            origin: glyph.origin,
            size: glyph.size
        )
        let transform = self.transform * rect.toTransform3D
        self.currentDrawContext?.drawGlyph(glyph, transform: transform)
    }

    public func commitDraw() {
        self.currentDrawContext?.commitContext()
    }

    func flush() {
        self.currentDrawContext?.flush()
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
