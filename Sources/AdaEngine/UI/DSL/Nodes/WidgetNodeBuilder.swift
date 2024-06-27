//
//  WidgetNodeBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

@MainActor
protocol WidgetNodeBuilder {
    typealias Context = _WidgetInputs

    func makeWidgetNode(context: Context) -> WidgetNode
}
