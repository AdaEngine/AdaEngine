//
//  EmptyWidget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

import Math

public struct EmptyWidget: Widget, WidgetNodeBuilder {
    public typealias Body = Never

    func makeWidgetNode(context: Context) -> WidgetNode {
        WidgetNode(content: self)
    }
}

public struct Spacer: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let minLength: Float?

    public init(minLength: Float? = nil) {
        self.minLength = minLength
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        SpacerWidgetNode(minLength: minLength, content: self)
    }
}

class SpacerWidgetNode: WidgetNode {
    let minLength: Float?

    init(minLength: Float?, content: Spacer) {
        self.minLength = minLength
        super.init(content: content)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero {
            return .zero
        }
        
        var size = proposal.replacingUnspecifiedDimensions()
        if let minLength {
            size = proposal.replacingUnspecifiedDimensions(by: Size(width: minLength, height: minLength))
            size.width = max(size.width, minLength)
            size.height = max(size.height, minLength)
        }

        if layoutProperties.stackOrientation == .horizontal {
            size.height = 0
        } else if layoutProperties.stackOrientation == .vertical {
            size.width = 0
        }

        return size
    }
}
