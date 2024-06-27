//
//  WidgetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct _ModifiedContent<Content: WidgetModifier>: Widget {

    public typealias Body = Never

    enum Storage {
        case makeView((_WidgetInputs) -> _WidgetOutputs)
        case makeViewList((_WidgetListInputs) -> _WidgetListOutputs)
    }

    let storage: Storage

    public static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs {
        let storage = view[\.storage].value
        switch storage {
        case .makeView(let block):
            return block(inputs)
        case .makeViewList(let block):
            let nodes = block(_WidgetListInputs(input: inputs)).outputs.map { $0.node }
            let node = LayoutWidgetContainerNode(
                layout: AnyLayout(inputs.layout),
                content: view.value,
                nodes: nodes
            )

            return _WidgetOutputs(node: node)
        }
    }

    public static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        let storage = view[\.storage].value
        switch storage {
        case .makeViewList(let block):
            return block(inputs)
        default:
            fatalError()
        }
    }
}

@MainActor
public protocol WidgetModifier {
    associatedtype Body: Widget
    typealias Content = _ModifiedContent<Self>

    @WidgetBuilder
    func body(content: Self.Content) -> Body

    static func _makeView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetInputs,
        body: @escaping (_WidgetInputs) -> _WidgetOutputs
    ) -> _WidgetOutputs

    static func _makeListView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetListInputs,
        body: @escaping (_WidgetListInputs) -> _WidgetListOutputs
    ) -> _WidgetListOutputs
}

extension WidgetModifier {
    public static func _makeView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetInputs,
        body: @escaping (_WidgetInputs) -> _WidgetOutputs
    ) -> _WidgetOutputs {
        let newBody = modifier.value.body(content: _ModifiedContent(storage: .makeView(body)))
        return Self.Body._makeView(_WidgetGraphNode(value: newBody), inputs: inputs)
    }

    public static func _makeListView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetListInputs,
        body: @escaping (_WidgetListInputs) -> _WidgetListOutputs
    ) -> _WidgetListOutputs {
        if let builder = modifier.value as? WidgetNodeBuilder {
            let node = builder.makeWidgetNode(context: inputs.input)
            let output = _WidgetOutputs(node: node)
            return _WidgetListOutputs(outputs: [output])
        }
        let newBody = modifier.value.body(content: _ModifiedContent(storage: .makeViewList(body)))
        return Self.Body._makeListView(_WidgetGraphNode(value: newBody), inputs: inputs)
    }
}

extension WidgetModifier {

    /// Returns a new modifier that is the result of concatenating
    /// `self` with `modifier`.
    @inlinable public func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}

public extension Widget {
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

public extension WidgetModifier where Body == Never {
    func body(content: Self.Content) -> Never {
        fatalError("We should call body when Body is Never type.")
    }
}

extension ModifiedContent: Widget where Modifier: WidgetModifier, Content: Widget {

    public var body: Never {
        fatalError()
    }

    public static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs {
        return Modifier._makeView(for: view[\.modifier], inputs: inputs) { inputs in
            return Content._makeView(view[\.content], inputs: inputs)
        }
    }

    public static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        return Modifier._makeListView(for: view[\.modifier], inputs: inputs) { inputs in
            let content = view[\.content]
            if let builder = content.value as? WidgetNodeBuilder {
                let node = builder.makeWidgetNode(context: inputs.input)
                let output = _WidgetOutputs(node: node)
                return _WidgetListOutputs(outputs: [output])
            }

            return Content._makeListView(content, inputs: inputs)
        }
    }

}

extension ModifiedContent : WidgetModifier where Content : WidgetModifier, Modifier : WidgetModifier {
    public static func _makeView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetInputs,
        body: @escaping (_WidgetInputs) -> _WidgetOutputs
    ) -> _WidgetOutputs {
        return Modifier._makeView(for: modifier[\.modifier], inputs: inputs) { inputs in
            let content = modifier[\.content]
            return Content._makeView(for: content, inputs: inputs, body: body)
        }
    }

    public static func _makeListView(
        for modifier: _WidgetGraphNode<Self>,
        inputs: _WidgetListInputs,
        body: @escaping (_WidgetListInputs) -> _WidgetListOutputs
    ) -> _WidgetListOutputs {
        return Modifier._makeListView(for: modifier[\.modifier], inputs: inputs) { inputs in
            let content = modifier[\.content]
            return Content._makeListView(for: content, inputs: inputs, body: body)
        }
    }
}

class WidgetModifierNode: WidgetContainerNode {
    override func performLayout() {
        for node in nodes {
            node.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
        }
    }
}
