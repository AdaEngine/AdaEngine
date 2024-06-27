//
//  BackgroundModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public extension Widget {
    func background(_ color: Color) -> some Widget {
        self.modifier(BackgroundWidget(content: self, backgroundContent: color))
    }

    func background<Content: Widget>(@WidgetBuilder _ content: () -> Content) -> some Widget {
        self.modifier(BackgroundWidget(content: self, backgroundContent: content()))
    }
}

struct BackgroundWidget<Content: Widget, BackgroundContent: Widget>: WidgetModifier, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let backgroundContent: BackgroundContent

    init(content: Content, backgroundContent: BackgroundContent) {
        self.content = content
        self.backgroundContent = backgroundContent
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        let backgroundNode = context.makeNode(from: self.backgroundContent)
        return BackgroundWidgetNode(
            backgroundNode: backgroundNode,
            content: content,
            inputs: _WidgetListInputs(input: context)
        )
    }
}

class BackgroundWidgetNode: WidgetModifierNode {
    let backgroundNode: WidgetNode

    init<Content>(
        backgroundNode: WidgetNode,
        content: Content,
        inputs: _WidgetListInputs
    ) where Content : Widget {
        self.backgroundNode = backgroundNode
        super.init(content: content, inputs: inputs)
    }

    override func draw(with context: GUIRenderContext) {
        self.backgroundNode.draw(with: context)
        super.draw(with: context)
    }

    override func performLayout() {
        self.backgroundNode.place(in: self.frame.origin, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
        super.performLayout()
    }
}

