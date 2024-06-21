//
//  WidgetTree.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
class WidgetTree<Content: Widget> {
    
    let rootView: Content
    private(set) var rootNode: WidgetNode
    
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
        self.contentNode.frame = self.frame
        self.contentNode.performLayout()
    }

    override func draw(with context: GUIRenderContext) {
        contentNode.draw(with: context)
    }
}
