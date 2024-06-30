//
//  View.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@_typeEraser(AnyView)
public protocol View {
    associatedtype Body: View

    @ViewBuilder
    @MainActor(unsafe)
    var body: Self.Body { get }

    @MainActor(unsafe) static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs
    @MainActor(unsafe) static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
}

extension View {
    @MainActor(unsafe)
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let resolvedInputs = inputs.resolveStorages(in: view.value)
        if let builder = view.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs)
            return _ViewOutputs(node: node)
        }

        let body = view[\.body]
        if let builder = body.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs)
            return _ViewOutputs(node: node)
        } else {
            let bodyNode = Self.Body._makeView(body, inputs: inputs).node
            let node = LayoutViewContainerNode(
                layout: AnyLayout(inputs.layout),
                content: view.value,
                nodes: [bodyNode]
            )
            resolvedInputs.registerNodeForStorages(node)
            return _ViewOutputs(node: node)
        }
    }

    @MainActor(unsafe)
    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        if let builder = view.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs.input)
            return _ViewListOutputs(outputs: [_ViewOutputs(node: node)])
        }
        
        let body = view[\.body]
        if let builder = body.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs.input)
            return _ViewListOutputs(outputs: [_ViewOutputs(node: node)])
        }

        let inputs = inputs.input.resolveStorages(in: body.value)
        return Self.Body._makeListView(body, inputs: _ViewListInputs(input: inputs))
    }
}

// MARK: - Debug

extension View {
    public static func printChanges() {
        ViewGraph.registerViewToDebugUpdate(self)
    }
}
