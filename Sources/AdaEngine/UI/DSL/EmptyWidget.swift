//
//  EmptyView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

public struct EmptyView: View, ViewNodeBuilder {
    public typealias Body = Never

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        ViewNode(content: self)
    }
}
