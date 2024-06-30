//
//  View+Color.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

extension Color: View, ViewNodeBuilder {

    public typealias Body = Never

    @MainActor
    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        return CanvasViewNode(content: self, drawBlock: { context, size in
            context.drawRect(Rect(origin: .zero, size: size), color: self)
        })
    }
}
