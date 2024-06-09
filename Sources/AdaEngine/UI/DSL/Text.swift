//
//  Text.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct Text: Widget, WidgetNodeBuilder {
    
    let text: String
    
    public init(_ text: String) {
        self.text = text
    }
    
    public var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = TextWidgetNode(
            parent: context.parent,
            stackIndex: 0,
            content: self
        )
        
        node.text = text
        node.font = context.widgetContext.font
        
        return node
    }
}
