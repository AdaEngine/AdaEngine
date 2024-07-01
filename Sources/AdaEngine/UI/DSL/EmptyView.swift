//
//  EmptyView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

public struct EmptyView: View, ViewNodeBuilder {
    public typealias Body = Never

    public init() {}

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        EmptyViewNode(content: self)
    }
}

final class EmptyViewNode: ViewNode {
    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return .zero
    }
}
