//
//  Divider.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 04.08.2024.
//

import Math

public struct Divider: View, ViewNodeBuilder {

    public init() {}

    public var body: Never {
        fatalError()
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        return DividerNode(content: self)
    }
}

final class DividerNode: ViewNode {
    override func draw(with context: UIGraphicsContext) {
        context.drawRect(Rect(origin: .zero, size: Size(width: frame.width, height: 1)), color: .gray)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
}
