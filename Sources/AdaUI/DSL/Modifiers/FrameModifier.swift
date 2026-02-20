//
//  FrameModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

import Math

public extension View {
    /// Positions this view within an invisible frame with the specified size.
    /// - Parameter width: A fixed width for the resulting view. If width is nil, the resulting view assumes this view’s sizing behavior.
    /// - Parameter height: A fixed height for the resulting view. If height is nil, the resulting view assumes this view’s sizing behavior.
    /// - Returns: A view with fixed dimensions of width and height, for the parameters that are non-nil.
    func frame(width: Float? = nil, height: Float? = nil) -> some View {
        self.modifier(
            _FrameViewModifier(
                content: self,
                frame: .size(width: width, height: height)
            )
        )
    }
}

struct _FrameViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never
    let content: Content

    let frame: FrameViewNode.Frame

    func buildViewNode(in context: BuildContext) -> ViewNode {
        FrameViewNode(
            frameRule: frame,
            content: content,
            contentNode: context.makeNode(from: content)
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
        switch frameRule {
        case .size(let width, let height):
            var newSize = self.contentNode.sizeThatFits(
                ProposedViewSize(
                    width: width,
                    height: height
                )
            )
            if let width {
                newSize.width = width
            }

            if let height {
                newSize.height = height
            }

            return newSize
        }
    }
}
