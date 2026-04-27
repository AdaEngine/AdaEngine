//
//  DebugDrawing.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.12.2025.
//

import AdaUtils
import Math

public struct _DebugViewDrawingOptions: OptionSet, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public extension _DebugViewDrawingOptions {
    static let drawViewOverlays = _DebugViewDrawingOptions(rawValue: 1 << 0)
}

public extension View {
    func _debugDrawing(_ options: _DebugViewDrawingOptions) -> some View {
        self.transformEnvironment(\.debugViewDrawingOptions) { value in
            value = options
        }
    }

    func debugOverlay(_ mode: UIDebugOverlayMode = .layoutBounds) -> some View {
        self.modifier(DebugOverlayModifier(mode: mode, content: self))
    }
}

struct DebugOverlayModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let mode: UIDebugOverlayMode
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        DebugOverlayModifierNode(
            contentNode: context.makeNode(from: content),
            content: content,
            mode: mode
        )
    }
}

final class DebugOverlayModifierNode: ViewModifierNode {
    private var mode: UIDebugOverlayMode

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        mode: UIDebugOverlayMode
    ) {
        self.mode = mode
        super.init(contentNode: contentNode, content: content)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let node = newNode as? DebugOverlayModifierNode else {
            return
        }

        if self.mode != node.mode {
            self.mode = node.mode
            self.invalidateNearestLayer()
        }
    }

    override func draw(with context: UIGraphicsContext) {
        var contentContext = context
        contentContext.environment = environment
        contentContext.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        contentNode.draw(with: contentContext)

        guard mode != .off else {
            return
        }

        let overlayState = owner as? UIInspectionOverlayStateProviding
        drawInspectionDebugOverlay(
            with: context,
            mode: mode,
            focusedNode: overlayState?.inspectionFocusedNode,
            hitTestNode: overlayState?.inspectionHitTestNode
        )
    }
}
