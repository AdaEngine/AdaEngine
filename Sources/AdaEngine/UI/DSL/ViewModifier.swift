//
//  ViewModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct _ModifiedContent<Content: ViewModifier>: View {

    public typealias Body = Never

    enum Storage {
        case makeView((_ViewInputs) -> _ViewOutputs)
        case makeViewList((_ViewListInputs) -> _ViewListOutputs)
    }

    let storage: Storage

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let storage = view[\.storage].value
        switch storage {
        case .makeView(let block):
            return block(inputs)
        case .makeViewList(let block):
            let nodes = block(_ViewListInputs(input: inputs)).outputs.map { $0.node }
            let node = LayoutViewContainerNode(
                layout: AnyLayout(inputs.layout),
                content: view.value,
                nodes: nodes
            )
            inputs.registerNodeForStorages(node)
            return _ViewOutputs(node: node)
        }
    }

    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        let storage = view[\.storage].value
        switch storage {
        case .makeViewList(let block):
            return block(inputs)
        default:
            fatalError()
        }
    }
}

public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ModifiedContent<Self>

    @ViewBuilder
    func body(content: Self.Content) -> Body

    static func _makeView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewInputs,
        body: @escaping (_ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs

    static func _makeListView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs
}

extension ViewModifier {
    @MainActor
    public static func _makeView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewInputs,
        body: @escaping (_ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        if let builder = modifier.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs)
            return _ViewOutputs(node: node)
        }
        let newBody = modifier.value.body(content: _ModifiedContent(storage: .makeView(body)))
        return Self.Body._makeView(_ViewGraphNode(value: newBody), inputs: inputs)
    }

    @MainActor
    public static func _makeListView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        if let builder = modifier.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs.input)
            let output = _ViewOutputs(node: node)
            return _ViewListOutputs(outputs: [output])
        }
        let newBody = modifier.value.body(content: _ModifiedContent(storage: .makeViewList(body)))
        return Self.Body._makeListView(_ViewGraphNode(value: newBody), inputs: inputs)
    }
}

extension ViewModifier {

    /// Returns a new modifier that is the result of concatenating
    /// `self` with `modifier`.
    @inlinable public func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}

public extension View {
    func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        return ModifiedContent(content: self, modifier: modifier)
    }
}

public struct ModifiedContent<Content, Modifier> {
    
    public var content: Content
    
    public var modifier: Modifier
    
    @inlinable public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

public extension ViewModifier where Body == Never {
    func body(content: Self.Content) -> Never {
        fatalError("We should call body when Body is Never type.")
    }
}

extension ModifiedContent: View where Modifier: ViewModifier, Content: View {

    public var body: Never {
        fatalError()
    }

    @MainActor
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        return Modifier._makeView(for: view[\.modifier], inputs: inputs) { inputs in
            return Content._makeView(view[\.content], inputs: inputs)
        }
    }
    
    @MainActor
    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        return Modifier._makeListView(for: view[\.modifier], inputs: inputs) { inputs in
            let content = view[\.content]
            if let builder = content.value as? ViewNodeBuilder {
                let node = builder.makeViewNode(inputs: inputs.input)
                let output = _ViewOutputs(node: node)
                return _ViewListOutputs(outputs: [output])
            }

            return Content._makeListView(content, inputs: inputs)
        }
    }

}

extension ModifiedContent : ViewModifier where Content : ViewModifier, Modifier : ViewModifier {
    @MainActor
    public static func _makeView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewInputs,
        body: @escaping (_ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        return Modifier._makeView(for: modifier[\.modifier], inputs: inputs) { inputs in
            let content = modifier[\.content]
            return Content._makeView(for: content, inputs: inputs, body: body)
        }
    }

    @MainActor
    public static func _makeListView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        return Modifier._makeListView(for: modifier[\.modifier], inputs: inputs) { inputs in
            let content = modifier[\.content]
            return Content._makeListView(for: content, inputs: inputs, body: body)
        }
    }
}

protocol _ViewInputsViewModifier {
    static func _makeModifier(_ modifier: _ViewGraphNode<Self>, inputs: inout _ViewInputs)
}

extension ViewModifier where Self: _ViewInputsViewModifier {
    @MainActor
    static func _makeView(
        for modifier: _ViewGraphNode<Self>,
        inputs: _ViewInputs,
        body: @escaping (_ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        var inputs = inputs
        Self._makeModifier(modifier, inputs: &inputs)

        if let builder = modifier.value as? ViewNodeBuilder {
            let node = builder.makeViewNode(inputs: inputs)
            return _ViewOutputs(node: node)
        }
        
        let newBody = modifier.value.body(content: _ModifiedContent(storage: .makeView(body)))
        return Self.Body._makeView(_ViewGraphNode(value: newBody), inputs: inputs)
    }
}
