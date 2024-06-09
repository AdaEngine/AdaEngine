//
//  HStack.swift
//
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct HStack<Content: Widget>: Widget, WidgetNodeBuilder {
    
    let content: Content
    
    public init(@WidgetBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        return WidgetStackContainerNode(
            axis: .horizontal,
            content: self,
            buildNodesBlock: {
                let containerNode = (self.content as? WidgetNodeBuilder)?.makeWidgetNode(context: context) as? WidgetContainerNode
                
                guard let containerNode else {
                    return []
                }
                
                return containerNode.nodes
            }
        )
    }
}
