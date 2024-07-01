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
        self.modifier(
            TransformViewEnvironmentModifier(
                content: self,
                keyPath: keyPath,
                block: block
            )
        )
    }

    func environment<Value>(
        _ keyPath: WritableKeyPath<ViewEnvironmentValues, Value>,
        _ newValue: Value
    ) -> some View {
        self.modifier(
            TransformViewEnvironmentModifier(
                content: self,
                keyPath: keyPath,
                block: { value in
                    value = newValue
                }
            )
        )
    }
}

struct TransformViewEnvironmentModifier<WrappedView: View, Value>: ViewModifier, _ViewInputsViewModifier {

    let content: WrappedView
    let keyPath: WritableKeyPath<ViewEnvironmentValues, Value>
    let block: (inout Value) -> Void

    func body(content: Content) -> some View {
        return content
    }

    static func _makeModifier(_ modifier: _ViewGraphNode<Self>, inputs: inout _ViewInputs) {
        var environment = inputs.environment
        modifier.value.block(&environment[keyPath: modifier.value.keyPath])
        inputs.environment = environment
    }
}
