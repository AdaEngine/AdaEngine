//
//  HStack.swift
//
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct HStack<Content: Widget>: Widget, WidgetNodeBuilder {
    
    let spacing: Float
    let content: Content
    
    public init(spacing: Float = 0, @WidgetBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        return WidgetStackContainerNode(
            axis: .horizontal,
            spacing: spacing,
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
