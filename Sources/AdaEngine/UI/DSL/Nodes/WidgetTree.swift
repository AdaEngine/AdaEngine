//
//  WidgetTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

@MainActor
class WidgetTree<Content: Widget> {
    
    let rootView: Content
    private(set) var rootNode: WidgetRootNode

    init(rootView: Content) {
        self.rootView = rootView
        
        let context = WidgetNodeBuilderContext(
            environment: WidgetEnvironmentValues()
        )
        
        let contentNode = Self.findFirstWidgetNodeBuilder(in: self.rootView, context: context)
        contentNode.storages = WidgetNodeBuilderUtils.findPropertyStorages(in: rootView, node: contentNode)
        self.rootNode = WidgetRootNode(contentNode: contentNode, content: rootView)
    }
    
    func renderGraph(renderContext: GUIRenderContext) {
        self.rootNode.draw(with: renderContext)
    }
    
    private static func findFirstWidgetNodeBuilder<T: Widget>(in content: T, context: WidgetNodeBuilderContext) -> WidgetNode {
        if let builder = content.body as? WidgetNodeBuilder {
            return builder.makeWidgetNode(context: context)
        } else {
            return self.findFirstWidgetNodeBuilder(in: content.body, context: context)
        }
    }
}

final class WidgetRootNode: WidgetNode {

    let contentNode: WidgetNode

    init<Root: Widget>(contentNode: WidgetNode, content: Root) {
        self.contentNode = contentNode
        super.init(content: content)
        self.contentNode.parent = self
    }

    override func performLayout() {
        let proposal = ProposedViewSize(width: self.frame.width, height: self.frame.height)

        self.contentNode.place(
            in: Point(self.frame.midX, self.frame.midY),
            anchor: .center,
            proposal: proposal
        )

        self.contentNode._printDebugNode()
    }

    override func update(_ deltaTime: TimeInterval) {
        contentNode.update(deltaTime)
    }

    override func draw(with context: GUIRenderContext) {
        contentNode.draw(with: context)
    }

    override func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        contentNode.hitTest(point, with: event)
    }

    override func point(inside point: Point, with event: InputEvent) -> Bool {
        contentNode.point(inside: point, with: event)
    }
}
