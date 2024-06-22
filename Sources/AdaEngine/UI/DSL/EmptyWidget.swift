//
//  EmptyWidget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.06.2024.
//

public struct EmptyWidget: Widget, WidgetNodeBuilder {
    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        WidgetNode(content: self)
    }
}

public struct Spacer: Widget, WidgetNodeBuilder {

    let minSpace: Float

    public init(minSpace: Float = 0) {
        self.minSpace = minSpace
    }

    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        SpacerWidgetNode(minSpace: minSpace, content: self)
    }
}

class SpacerWidgetNode: WidgetNode {
    let minSpace: Float

    init(minSpace: Float, content: any Widget) {
        self.minSpace = minSpace
        super.init(content: content)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        super.sizeThatFits(proposal, usedByParent: usedByParent)
    }
}
