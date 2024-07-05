//
//  FrameModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public extension View {
    func frame(width: Float? = nil, height: Float? = nil) -> some View {
        self.modifier(
            FrameViewModifier(
                content: self,
                frame: .size(width: width, height: height)
            )
        )
    }
}

struct FrameViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never
    let content: Content

    let frame: FrameViewNode.Frame

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        FrameViewNode(
            frameRule: frame,
            content: content,
            contentNode: inputs.makeNode(from: content)
        )
    }
}

final class FrameViewNode: ViewModifierNode {

    enum Frame {
        case size(width: Float?, height: Float?)
    }

    let frameRule: Frame

    init<Content: View>(frameRule: Frame, content: Content, contentNode: ViewNode) {
        self.frameRule = frameRule
        super.init(contentNode: contentNode, content: content)
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
