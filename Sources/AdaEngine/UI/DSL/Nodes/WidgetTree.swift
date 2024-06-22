//
//  WidgetTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
class WidgetTree<Content: Widget> {
    
    let rootView: Content
    private(set) var rootNode: WidgetRootNode

    init(rootView: Content) {
        self.rootView = rootView
        
        let context = WidgetNodeBuilderContext(
            widgetContext: WidgetContextValues()
        )
        
        let contentNode = Self.findFirstWidgetNodeBuilder(in: self.rootView, context: context)
        contentNode.storages = WidgetStorageReflection.findStorages(in: rootView, node: contentNode)
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

    init(contentNode: WidgetNode, content: any Widget) {
        self.contentNode = contentNode
        super.init(content: content)
    }

    override func performLayout() {
        let size = self.contentNode.sizeThatFits(ProposedViewSize(width: self.frame.width, height: self.frame.height), usedByParent: true)
        self.contentNode.frame.size.width = min(self.frame.width, size.width)
        self.contentNode.frame.size.height = min(self.frame.height, size.height)
        self.contentNode.performLayout()

        self.contentNode._printDebugNode()
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
