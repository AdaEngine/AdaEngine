//
//  FrameModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public extension Widget {
    func frame(width: Float? = nil, height: Float? = nil) -> some Widget {
        self.modifier(
            FrameWidgetModifier(
                content: self,
                frame: .size(width: width, height: height)
            )
        )
    }
}

struct FrameWidgetModifier<Content: Widget>: WidgetModifier, WidgetNodeBuilder {

    typealias Body = Never
    let content: Content

    let frame: FrameWidgetNode.Frame

    func makeWidgetNode(context: Context) -> WidgetNode {
        FrameWidgetNode(frameRule: frame, content: content, context: context)
    }
}

final class FrameWidgetNode: WidgetModifierNode {

    enum Frame {
        case size(width: Float?, height: Float?)
    }

    let frameRule: Frame

    init<Content: Widget>(frameRule: Frame, content: Content, context: WidgetNodeBuilderContext) {
        self.frameRule = frameRule
        super.init(content: content, context: context)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        var newSize = super.sizeThatFits(proposal)

        switch frameRule {
        case .size(let width, let height):
            if let width {
                newSize.width = width
            }

            if let height {
                newSize.height = height
            }
        }

        return newSize
    }
}
