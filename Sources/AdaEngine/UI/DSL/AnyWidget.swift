//
//  AnyWidget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public struct AnyWidget: Widget {

    public typealias Body = Never

    let content: any Widget

    public init<T: Widget>(_ widget: T) {
        self.content = widget
    }

    public init(_ widget: any Widget) {
        self.content = widget
    }

    public static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs {
        let content = view[\.content].value
        return self.makeView(content, inputs: inputs)
    }

    public static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        let content = view[\.content].value
        return self.makeListView(content, inputs: inputs)
    }

    private static func makeView<T: Widget>(_ view: T, inputs: _WidgetInputs) -> _WidgetOutputs {
        T._makeView(_WidgetGraphNode(value: view), inputs: inputs)
    }

    private static func makeListView<T: Widget>(_ view: T, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        T._makeListView(_WidgetGraphNode(value: view), inputs: inputs)
    }
}
