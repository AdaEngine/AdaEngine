//
//  Widget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Foundation

@MainActor
public protocol Widget {
    associatedtype Body: Widget
    
    @WidgetBuilder
    var body: Self.Body { get }

    static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs
    static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs
}

extension Widget {
    public static func _makeView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetInputs) -> _WidgetOutputs {
        if let builder = view.value as? WidgetNodeBuilder {
            let node = builder.makeWidgetNode(context: inputs)
            return _WidgetOutputs(node: node)
        }

        let body = view[\.body]
        if body.value is WidgetNodeBuilder {
            return Self.Body._makeView(body, inputs: inputs)
        }

        let listInputs = _WidgetListInputs(input: inputs)
        let listView = Body._makeListView(body, inputs: listInputs)
        let node = LayoutWidgetContainerNode(
            layout: AnyLayout(inputs.layout),
            content: body.value,
            nodes: listView.outputs.map { $0.node }
        )
        return _WidgetOutputs(node: node)
    }

    public static func _makeListView(_ view: _WidgetGraphNode<Self>, inputs: _WidgetListInputs) -> _WidgetListOutputs {
        if let builder = view.value as? WidgetNodeBuilder {
            let node = builder.makeWidgetNode(context: inputs.input)
            return _WidgetListOutputs(outputs: [_WidgetOutputs(node: node)])
        }
        
        let body = view[\.body]
        if let builder = body.value as? WidgetNodeBuilder {
            let node = builder.makeWidgetNode(context: inputs.input)
            return _WidgetListOutputs(outputs: [_WidgetOutputs(node: node)])
        }

        return Self.Body._makeListView(body, inputs: inputs)
    }
}

@MainActor
public struct _WidgetInputs {
    var layout: any Layout = VStackLayout()
    var environment: WidgetEnvironmentValues

    func makeNode<T: Widget>(from content: T) -> WidgetNode {
        return T._makeView(_WidgetGraphNode(value: content), inputs: self).node
    }
}

@MainActor
public struct _WidgetOutputs {
    var node: WidgetNode
}

@MainActor
public struct _WidgetListInputs {
    let input: _WidgetInputs
}

@MainActor
public struct _WidgetListOutputs {
    var outputs: [_WidgetOutputs]
}

@MainActor
public struct _WidgetGraphNode<Value>: Equatable {

    let value: Value

    init(value: Value) {
        self.value = value
    }

    subscript<U>(keyPath: KeyPath<Value, U>) -> _WidgetGraphNode<U> {
        _WidgetGraphNode<U>(value: self.value[keyPath: keyPath])
    }

    public static func == (lhs: _WidgetGraphNode<Value>, rhs: _WidgetGraphNode<Value>) -> Bool where Value: Equatable {
        lhs.value == rhs.value
    }

    public static func == (lhs: _WidgetGraphNode<Value>, rhs: _WidgetGraphNode<Value>) -> Bool {
        // if its pod, we can compare it together using memcmp.
        if _isPOD(Value.self) {
            let memSize = MemoryLayout<Value>.size
            return withUnsafePointer(to: lhs.value) { lhsPtr in
                withUnsafePointer(to: rhs.value) { rhsPtr in
                    memcmp(lhsPtr, rhsPtr, memSize) == 0
                }
            }
        } else {
            // For another hand we should compare it using reflection or smth else

            return false
        }
    }
}

