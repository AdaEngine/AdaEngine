//
//  UIGraphicsContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

import AdaApp
import AdaText
import AdaRender
import AdaUtils
import Math
import Collections

// TODO: Clip Mask

/// Special object to render user interface on the screen.
/// Context use orthogonal projection.
public struct UIGraphicsContext: Sendable {

    /// Returns current transform.
    public private(set) var transform: Transform3D = .identity
    private var clipPath: Path?

    public var opacity: Float = 1

    /// Values passed for render context.
    public var environment: EnvironmentValues = EnvironmentValues()

    // Used for internal and debug values.
    package var _environment: EnvironmentValues = EnvironmentValues()

    private(set) var commandQueue = CommandQueue()

    public init() { }

    public init(texture: RenderTexture) {
        var camera = Camera(renderTarget: texture)
//        camera.isActive = true
//        camera.projection = .orthographic
//        self.camera = camera
    }
    
    public mutating func beginDraw(in size: Size, scaleFactor: Float) {
        let view = Transform3D.orthographic(
            left: 0,
            right: size.width * scaleFactor,
            top: 0,
            bottom: -size.height * scaleFactor,
            zNear: 0,
            zFar: 1000
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
        self.commandQueue.push(.drawQuad(transform: transform, texture: texture, color: applyOpacityIfNeeded(color)))
    }
    
    /// Paints the area of the ellipse that fits inside the provided rectangle, using the fill color in the current graphics state.
    public func drawEllipse(
        in rect: Rect, 
        color: Color,
        thickness: Float = 1
    ) {
        let transform = self.transform * rect.toTransform3D
        self.commandQueue.push(
            .drawCircle(
                transform: transform,
                thickness: thickness,
                fade: 0.005,
                color: applyOpacityIfNeeded(color)
            )
        )
    }

    public func drawLine(start: Vector2, end: Vector2, lineWidth: Float, color: Color) {
        let start = (transform * Vector4(start.x, start.y, 0, 1))
        let end = (transform * Vector4(end.x, end.y, 0, 1))
        self.commandQueue.push(
            .drawLine(
                start: start.xyz,
                end: end.xyz,
                lineWidth: lineWidth,
                color: applyOpacityIfNeeded(color)
            )
        )
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
        self.commandQueue.push(.drawText(textLayout: textLayout, transform: transform))
    }

    public func draw(_ path: Path) {
        self.commandQueue.push(.drawPath(path))
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
        self.commandQueue.push(.drawGlyph(glyph, transform: transform))
    }

    public func commitDraw() {
        self.commandQueue.push(.commit)
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

extension UIGraphicsContext {
    final class CommandQueue: @unchecked Sendable {
        var commands: [DrawCommand] = []

        // We expected, that draw commands will be added only on main thread
        func push(_ command: DrawCommand) {
            MainActor.assumeIsolated { [command] in
                self.commands.append(command)
            }
        }
    }

    enum DrawCommand: Sendable {
        case setLineWidth(Float)
        case drawLine(start: Vector3, end: Vector3, lineWidth: Float, color: Color)

        case drawQuad(transform: Transform3D, texture: Texture2D? = nil, color: Color)
        case drawCircle(
            transform: Transform3D,
            thickness: Float,
            fade: Float,
            color: Color
        )
        case drawPath(Path)

        case drawText(textLayout: TextLayoutManager, transform: Transform3D)
        case drawGlyph(_ glyph: Glyph, transform: Transform3D)
        case commit
    }
}

extension UIGraphicsContext.DrawCommand {
    static func drawQuad(position: Vector3, size: Vector2, texture: Texture2D?, color: Color) -> Self {
        let transform = Transform3D(translation: position) * Transform3D(scale: Vector3(size, 1))
        return .drawQuad(transform: transform, texture: texture, color: color)
    }

    static func drawCircle(
        position: Vector3,
        rotation: Vector3,
        radius: Float,
        thickness: Float,
        fade: Float,
        color: Color
    ) -> Self {
        let transform = Transform3D(translation: position)
        * Transform3D(quat: Quat(axis: [1, 0, 0], angle: rotation.x))
        * Transform3D(quat: Quat(axis: [0, 1, 0], angle: rotation.y))
        * Transform3D(quat: Quat(axis: [0, 0, 1], angle: rotation.z))
        * Transform3D(scale: Vector3(radius))

        return .drawCircle(transform: transform, thickness: thickness, fade: fade, color: color)
    }
}
