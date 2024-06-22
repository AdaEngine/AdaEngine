//
//  ForEach.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.06.2024.
//

public struct ForEach<Item, Content: Widget>: Widget, WidgetNodeBuilder {

    let data: [Item]
    var content: (Item) -> Content

    public init(_ data: [Item], @WidgetBuilder content: @escaping (Item) -> Content) {
        self.data = data
        self.content = content
    }

    public var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        WidgetContainerNode(content: self, buildNodesBlock: {
            let nodes = data.compactMap { item in
                (content(item) as? WidgetNodeBuilder)?.makeWidgetNode(context: context)
            }
            
            return nodes
        })
    }
}
