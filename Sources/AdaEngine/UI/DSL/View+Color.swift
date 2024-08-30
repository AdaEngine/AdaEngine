//
//  View+Color.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

extension Color: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    @MainActor
    func buildViewNode(in context: BuildContext) -> ViewNode {
        return CanvasViewNode(content: self, drawBlock: { context, size in
            if context.opacity == 1 {
                context.opacity = self.alpha
            }
            context.drawRect(Rect(origin: .zero, size: size), color: self)
        })
    }
}
