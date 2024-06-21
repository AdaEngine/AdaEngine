//
//  WidgetNodeBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

struct WidgetNodeBuilderContext {
    var widgetContext: WidgetContextValues
}

protocol WidgetNodeBuilder {
    
    typealias Context = WidgetNodeBuilderContext
    
    func makeWidgetNode(context: Context) -> WidgetNode
}
