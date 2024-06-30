//
//  AnyView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

@frozen
public struct AnyView: View {

    public typealias Body = Never

    let content: any View

    public init<T: View>(_ view: T) {
        self.content = view
    }

    public init<V: View>(erasing view: V) {
        self.content = view
    }

    @MainActor(unsafe)
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let content = view[\.content].value
        return self.makeView(content, inputs: inputs)
    }

    @MainActor(unsafe)
    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        let content = view[\.content].value
        return self.makeListView(content, inputs: inputs)
    }

    private static func makeView<T: View>(_ view: T, inputs: _ViewInputs) -> _ViewOutputs {
        T._makeView(_ViewGraphNode(value: view), inputs: inputs)
    }

    private static func makeListView<T: View>(_ view: T, inputs: _ViewListInputs) -> _ViewListOutputs {
        T._makeListView(_ViewGraphNode(value: view), inputs: inputs)
    }
}
