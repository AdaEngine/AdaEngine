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
        self.rootNode = contentNode
    }
    
    func invalidate(rect: Rect) {
        rootNode.invalidateContent()
    }
    
    func renderGraph(renderContext: GUIRenderContext) {
        self.rootNode.renderNode(context: renderContext)
    }
    
    private static func findFirstWidgetNodeBuilder<T: Widget>(in content: T, context: WidgetNodeBuilderContext) -> WidgetNode {
        if let builder = content.body as? WidgetNodeBuilder {
            return builder.makeWidgetNode(context: context)
        } else {
            return self.findFirstWidgetNodeBuilder(in: content.body, context: context)
        }
    }
}
