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

/// An immediate mode drawing destination, and its current state.
///
/// Use a context to execute 2D drawing primitives.
///
/// ```swift
/// // Draw plain rect.
/// func draw(in context: inout UIGraphicsContext) {
///     context.drawRect(Rect(x: 0, y: 0, width: 100, height: 30), color: .red)
/// }
/// ```
///
/// ```swift
/// // Draw rect with scale and opacity
/// func draw(in context: inout UIGraphicsContext) {
///     var context = context
///     context.opacity = 0.5
///     context.scaledBy(x: 2, y: 2)
///     context.drawRect(Rect(x: 0, y: 0, width: 100, height: 30), color: .red)
/// }
/// ```
///
/// The context has access to an ``AdaUtils/EnvironmentValues`` instance called ``environment`` that’s initially copied from the environment of its enclosing view or entity. You can also access values stored in the environment for your own purposes.
public struct UIGraphicsContext: Sendable {

    /// Returns current transform.
    public private(set) var transform: Transform3D = .identity
    private var clipPath: Path?

    /// The opacity of drawing operations in the context.
    ///
    /// Set this value to affect the opacity of content that you subsequently draw into the context.
    /// Changing this value has no impact on the content you previously drew into the context.
    public var opacity: Float = 1

    /// The environment associated with the graphics context.
    public var environment: EnvironmentValues = EnvironmentValues()

    // Used for internal and debug values.
    package var _environment: EnvironmentValues = EnvironmentValues()

    private(set) var commandQueue = CommandQueue()

    /// Create graphics context.
    public init() { }

    /// Appends the given transform to the context’s existing transform.
    /// - Parameter matrix: A transform to append to the existing transform.
    public mutating func concatenate(_ transform: Transform3D) {
        self.transform = transform * self.transform
    }

    /// Moves subsequent drawing operations by an amount in each dimension.
    /// - Parameter x: The amount to move in the horizontal direction.
    /// - Parameter y: The amount to move in the vertical direction.
    public mutating func translateBy(x: Float, y: Float) {
        let translationMatrix = Transform3D(translation: [x, y, 0])
        self.transform = translationMatrix * self.transform
    }

    /// Scales subsequent drawing operations by an amount in each dimension.
    /// - Parameter x: The amount to scale in the horizontal direction.
    /// - Parameter y: The amount to scale in the vertical direction.
    public mutating func scaleBy(x: Float, y: Float) {
        let scaleMatrix = Transform3D(scale: [x, y, 1])
        self.transform = scaleMatrix * self.transform
    }

    /// Rotates subsequent drawing operations by an angle.
    /// - Parameter angle: The amount to rotate.
    public mutating func rotate(by angle: Angle) {
        self.transform = Transform3D(quat: Quat(axis: Vector3(0, 0, 1), angle: angle.radians)) * self.transform
    }

    /// Clear any applied transform
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

    /// Draws line into the graphics context.
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

    // MARK: - Text Drawing

    /// Draws text into the graphics context.
    public func drawText(in rect: Rect, from textLayout: TextLayoutManager) {
        let transform = self.transform * rect.toTransform3D
        self.commandQueue.push(
            .drawText(
                textLayout: textLayout,
                transform: transform
            )
        )
    }

    /// Draws attributed text into the graphics context.
    public func drawText(_ text: AttributedText, in rect: Rect) {
        let layout = TextLayoutManager()
        layout.setTextContainer(TextContainer(text: text))
        layout.fitToSize(rect.size)
        let transform = self.transform * rect.toTransform3D
        self.commandQueue.push(.drawText(textLayout: layout, transform: transform))
    }

    /// Draws path into the graphics context.
    public func draw(_ path: Path) {
        self.commandQueue.push(.drawPath(path))
    }

    /// Draws text line into the graphics context.
    public func draw(_ line: TextLine) {
        for run in line {
            self.draw(run)
        }
    }

    /// Draws text run into the graphics context.
    public func draw(_ run: TextRun) {
        for glyph in run {
            self.draw(glyph)
        }
    }

    /// Draws text glyph into the graphics context.
    public func draw(_ glyph: Glyph) {
        // Use identity transform - glyph.position already contains correct pixel coordinates
        // The current context transform will be applied during tessellation
        self.commandQueue.push(.drawGlyph(glyph, transform: self.transform))
    }

    /// Commits draws.
    public func commitDraw() {
        self.commandQueue.push(.commit)
    }

    @inlinable
    func applyOpacityIfNeeded(_ color: Color) -> Color {
        if color == .clear {
            return color
        }

        return color.opacity(self.opacity)
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

    /// Returns recorded draw commands.
    /// Use it for tesselation.
    public func getDrawCommands() -> [DrawCommand] {
        self.commandQueue.commands
    }

    final class CommandQueue: @unchecked Sendable {
        var commands: [DrawCommand] = []

        // We expected, that draw commands will be added only on main thread
        func push(_ command: DrawCommand) {
            MainActor.assumeIsolated { [command] in
                self.commands.append(command)
            }
        }
    }

    /// The commands that Graphic Context recorded.
    public enum DrawCommand: Sendable {
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
