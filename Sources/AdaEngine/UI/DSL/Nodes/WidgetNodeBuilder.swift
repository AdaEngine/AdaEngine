//
//  WidgetNodeBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

@MainActor
protocol WidgetNodeBuilder {
    typealias Context = WidgetNodeBuilderContext

    func makeWidgetNode(context: Context) -> WidgetNode
}

@MainActor
struct WidgetNodeBuilderContext {
    var environment: WidgetEnvironmentValues

    func makeNode<T: Widget>(from content: T) -> WidgetNode {
        guard let builder = WidgetNodeBuilderUtils.findNodeBuilder(in: content) else {
            fatalError()
        }

        return builder.makeWidgetNode(context: self)
    }
}
