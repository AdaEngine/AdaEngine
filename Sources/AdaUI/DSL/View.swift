//
//  View.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

/// A type that represents part of your user interface and provides modifiers that you use to configure views.
@_typeEraser(AnyView)
@MainActor @preconcurrency 
public protocol View {
    /// The type of view representing the body of this view.
    associatedtype Body: View

    /// The content and behavior of the view.
    @ViewBuilder @MainActor @preconcurrency
    var body: Self.Body { get }

    @MainActor @preconcurrency static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs
    @MainActor @preconcurrency static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
}

extension View {
    @MainActor @preconcurrency
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let resolvedInputs = inputs.resolveStorages(in: view.value)

        if let builder = view.value as? ViewNodeBuilder {
            let node = builder.buildViewNode(in: inputs)
            return _ViewOutputs(node: node)
        }

        let body = view[\.body]
        if let builder = body.value as? ViewNodeBuilder {
            let node = builder.buildViewNode(in: inputs)
            resolvedInputs.registerNodeForStorages(node)
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

    @MainActor @preconcurrency
    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        if let builder = view.value as? ViewNodeBuilder {
            let node = builder.buildViewNode(in: inputs.input)
            return _ViewListOutputs(outputs: [_ViewOutputs(node: node)])
        }
        
        let body = view[\.body]
        if let builder = body.value as? ViewNodeBuilder {
            let node = builder.buildViewNode(in: inputs.input)
            return _ViewListOutputs(outputs: [_ViewOutputs(node: node)])
        }

        let inputs = inputs.input.resolveStorages(in: body.value)
        return Self.Body._makeListView(body, inputs: _ViewListInputs(input: inputs))
    }
}

extension View where Body == Never {
    var body: Never {
        fatalError()
    }
}

public extension Never {
    typealias Body = Never

    var body: Never {
        fatalError()
    }
}

extension Never: View { }

extension Optional: View where Wrapped: View {
    public var body: some View {
        switch self {
        case .none:
            EmptyView()
        case .some(let wrapped):
            wrapped
        }
    }
}

// MARK: - Debug

extension View {
    @MainActor
    public static func _printChanges() {
        ViewGraph.registerViewToDebugUpdate(self)
    }
}
