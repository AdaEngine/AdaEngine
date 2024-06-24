//
//  TransformWidgetEnvironmentModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public extension Widget {
    func transformEnvironment<Value>(
        _ keyPath: WritableKeyPath<WidgetEnvironmentValues, Value>,
        block: @escaping (inout Value) -> Void
    ) -> some Widget {
        TransformWidgetEnvironmentModifier(
            content: self,
            keyPath: keyPath,
            block: block
        )
    }

    func environment<Value>(
        _ keyPath: WritableKeyPath<WidgetEnvironmentValues, Value>,
        _ newValue: Value
    ) -> some Widget {
        TransformWidgetEnvironmentModifier(
            content: self,
            keyPath: keyPath,
            block: { value in
                value = newValue
            }
        )
    }
}

struct TransformWidgetEnvironmentModifier<Content: Widget, Value>: Widget, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let keyPath: WritableKeyPath<WidgetEnvironmentValues, Value>
    let block: (inout Value) -> Void

    func makeWidgetNode(context: Context) -> WidgetNode {
        var environment = context.environment
        block(&environment[keyPath: keyPath])

        let newContext = Context(environment: environment)
        if let node = WidgetNodeBuilderUtils.findNodeBuilder(in: content)?.makeWidgetNode(context: newContext) {
            return node
        } else {
            fatalError("Fail to find builder")
        }
    }
}
