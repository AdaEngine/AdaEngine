//
//  WidgetStackContainerNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

class WidgetStackContainerNode: WidgetContainerNode {

    enum StackAxis {
        case horizontal
        case vertical
        case depth
    }

    let axis: StackAxis
    let spacing: Float

    init(axis: StackAxis, spacing: Float, content: any Widget, buildNodesBlock: @escaping BuildContentBlock) {
        self.axis = axis
        self.spacing = spacing

        super.init(content: content, buildNodesBlock: buildNodesBlock)
    }
    
    // swiftlint:disable:next function_body_length
    override func performLayout() {
        if frame == .zero { return }

        let count = self.nodes.count
        var origin: Point = .zero
        var previousSize: Size = .zero

        for node in self.nodes {
            var size: Size = .zero

            switch axis {
            case .horizontal:
                var proposalWidth = ((self.frame.size.width) / Float(count)) - (Float(count) * self.spacing)
                let proposalHeight = self.frame.height

                let proposal = ProposedViewSize(
                    width: proposalWidth,
                    height: proposalHeight
                )

                size = node.sizeThatFits(proposal)
            case .vertical:
                let proposalWidth = self.frame.width
                var proposalHeight = ((self.frame.size.height) / Float(count)) - (Float(count) * self.spacing)

                let proposal = ProposedViewSize(
                    width: proposalWidth,
                    height: proposalHeight
                )

                size = node.sizeThatFits(proposal)
            case .depth:
                let proposal = ProposedViewSize(
                    width: frame.width,
                    height: frame.height
                )
                size = node.sizeThatFits(proposal)
            }

            previousSize += size
            node.frame.size = size
            node.frame.origin = origin

            node.performLayout()

            switch axis {
            case .horizontal:
                origin.x += spacing + size.width
            case .vertical:
                origin.y += spacing + size.height
            case .depth:
                continue
            }
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        super.sizeThatFits(proposal, usedByParent: usedByParent)
    }

    override func debugDescription(hierarchy: Int = 0, identation: Int = 2) -> String {
        let indent = String(repeating: " ", count: hierarchy * identation)
        var string = super.debugDescription(hierarchy: hierarchy)
        string.append("\n\(indent)- axis: \(axis)")
        return string
    }
}
