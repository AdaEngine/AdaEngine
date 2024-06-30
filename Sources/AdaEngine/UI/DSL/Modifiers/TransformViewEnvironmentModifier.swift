//
//  TransformViewEnvironmentModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public extension View {
    func transformEnvironment<Value>(
        _ keyPath: WritableKeyPath<ViewEnvironmentValues, Value>,
        block: @escaping (inout Value) -> Void
    ) -> some View {
        TransformViewEnvironmentModifier(
            content: self,
            keyPath: keyPath,
            block: block
        )
    }

    func environment<Value>(
        _ keyPath: WritableKeyPath<ViewEnvironmentValues, Value>,
        _ newValue: Value
    ) -> some View {
        TransformViewEnvironmentModifier(
            content: self,
            keyPath: keyPath,
            block: { value in
                value = newValue
            }
        )
    }
}

struct TransformViewEnvironmentModifier<Content: View, Value>: View, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let keyPath: WritableKeyPath<ViewEnvironmentValues, Value>
    let block: (inout Value) -> Void

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        var environment = inputs.environment
        block(&environment[keyPath: keyPath])

        let newContext = _ViewInputs(environment: environment)
        return Content._makeView(_ViewGraphNode(value: content), inputs: newContext).node
    }
}
