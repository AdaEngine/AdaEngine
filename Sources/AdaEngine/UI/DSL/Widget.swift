//
//  Widget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
public protocol Widget {
    associatedtype Body: Widget
    
    @WidgetBuilder
    var body: Self.Body { get }
}

// TODO: Move

extension Color: Widget, WidgetNodeBuilder {
    
    public var body: Never {
        fatalError()
    }

    @MainActor
    func makeWidgetNode(context: Context) -> WidgetNode {
        return CanvasWidgetNode(content: self, drawBlock: { context, rect in
            context.drawRect(rect, color: self)
        })
    }
}
