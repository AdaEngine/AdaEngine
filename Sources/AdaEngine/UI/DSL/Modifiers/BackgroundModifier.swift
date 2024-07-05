//
//  BackgroundModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public extension View {
    func background(_ color: Color) -> some View {
        self.modifier(BackgroundView(content: self, backgroundContent: color))
    }

    func background<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        self.modifier(BackgroundView(content: self, backgroundContent: content()))
    }
}

struct BackgroundView<Content: View, BackgroundContent: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let backgroundContent: BackgroundContent

    init(content: Content, backgroundContent: BackgroundContent) {
        self.content = content
        self.backgroundContent = backgroundContent
    }

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let backgroundNode = inputs.makeNode(from: self.backgroundContent)
        let contentNode = inputs.makeNode(from: self.content)
        return BackgroundViewNode(
            backgroundNode: backgroundNode,
            content: content,
            contentNode: contentNode
        )
    }
}

class BackgroundViewNode: ViewModifierNode {
    let backgroundNode: ViewNode

    init<Content>(
        backgroundNode: ViewNode,
        content: Content,
        contentNode: ViewNode
    ) where Content : View {
        self.backgroundNode = backgroundNode
        super.init(contentNode: contentNode, content: content)
    }

    override func merge(_ otherNode: ViewNode) {
        guard let otherNode = otherNode as? BackgroundViewNode else {
            return
        }

        super.merge(otherNode)
        self.contentNode.merge(otherNode.contentNode)
        self.backgroundNode.merge(otherNode.backgroundNode)
    }

    override func draw(with context: inout GUIRenderContext) {
        self.backgroundNode.draw(with: &context)
        super.draw(with: &context)
    }

    override func performLayout() {
        self.backgroundNode.place(in: self.frame.origin, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
        super.performLayout()
    }
}
