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
    /// ```
    func glassEffect(_ style: GlassEffectStyle = .regular) -> some View {
        self.modifier(GlassEffectModifier(content: self, configuration: style.configuration))
    }

    /// Applies the Liquid Glass effect using a custom configuration.
    func glassEffect(configuration: GlassEffectConfiguration) -> some View {
        self.modifier(GlassEffectModifier(content: self, configuration: configuration))
    }
}

struct GlassEffectModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: Content
    let configuration: GlassEffectConfiguration

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let contentNode = context.makeNode(from: content)
        let node = GlassEffectViewNode(contentNode: contentNode, content: content)
        node.configuration = configuration
        return node
    }
}

final class GlassEffectViewNode: ViewModifierNode {
    var configuration: GlassEffectConfiguration = GlassEffectConfiguration()

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.translateBy(x: frame.origin.x, y: -frame.origin.y)

        let scaleFactor = max(ctx.environment.scaleFactor, 1)
        let localFrame = Rect(origin: .zero, size: frame.size)
        // Bake the current context transform into the draw command, mirroring how drawRect works.
        let worldTransform = ctx.transform * localFrame.toTransform3D
        ctx.commandQueue.push(
            .drawGlassRect(
                transform: worldTransform,
                halfSize: Vector2(frame.width * 0.5, frame.height * 0.5),
                configuration: configuration,
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
    }
}
