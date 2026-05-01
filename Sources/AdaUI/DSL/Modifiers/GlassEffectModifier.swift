//
//  GlassEffectModifier.swift
//  AdaEngine
//

import Math

public extension View {
    /// Applies the Liquid Glass effect to this view using a predefined style.
    ///
    /// The glass element renders behind the view's content, sampling and blurring
    /// the scene below it to produce a frosted-glass appearance.
    ///
    /// ```swift
    /// Text("Hello")
    ///     .padding()
    ///     .glassEffect()
    ///
    /// Text("Hello")
    ///     .padding()
    ///     .glassEffect(.regular, in: .rect(cornerRadius: 16))
    /// ```
    func glassEffect(_ style: Glass = .regular, in shape: some Shape = CapsuleShape()) -> some View {
        self.modifier(GlassEffectModifier(content: self, configuration: style, shape: shape))
    }
}

struct GlassEffectModifier<Content: View, S: Shape>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: Content
    let configuration: Glass
    let shape: S

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let contentNode = context.makeNode(from: content)
        let node = GlassEffectViewNode(contentNode: contentNode, content: content)
        node.configuration = configuration
        node.shape = shape
        return node
    }
}

final class GlassEffectViewNode: ViewModifierNode {
    var configuration: Glass = Glass()
    var shape: any Shape = CapsuleShape()

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.translateBy(x: frame.origin.x, y: -frame.origin.y)

        guard configuration.opacity > 0 else {
            contentNode.draw(with: ctx)
            if ctx.environment.debugViewDrawingOptions.contains(.drawViewOverlays) {
                ctx.drawDebugBorders(frame.size, color: debugNodeColor)
            }
            return
        }

        let scaleFactor = max(ctx.environment.scaleFactor, 1)
        let localFrame = Rect(origin: .zero, size: frame.size)
        let worldTransform = ctx.transform * localFrame.toTransform3D

        var config = configuration
        config.cornerRadius = resolvedCornerRadius()

        ctx.commandQueue.push(
            .drawGlassRect(
                transform: worldTransform,
                halfSize: Vector2(frame.width * 0.5, frame.height * 0.5),
                configuration: config,
                scaleFactor: scaleFactor
            )
        )

        contentNode.draw(with: ctx)

        if ctx.environment.debugViewDrawingOptions.contains(.drawViewOverlays) {
            ctx.drawDebugBorders(frame.size, color: debugNodeColor)
        }
    }

    override func update(from newNode: ViewNode) {
        guard let other = newNode as? GlassEffectViewNode else { return }
        super.update(from: other)
        self.configuration = other.configuration
        self.shape = other.shape
    }

    private func resolvedCornerRadius() -> Float {
        switch shape {
        case is RectangleShape:
            return 0
        case let rounded as RoundedRectangleShape:
            return rounded.cornerRadius
        default:
            return min(frame.width, frame.height) * 0.5
        }
    }
}
