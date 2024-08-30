//
//  OnChangeModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 17.07.2024.
//

public extension View {
    /// Adds a modifier for this view that fires an action when a specific value changes.
    /// - Parameter value: The value to check against when determining whether to run the closure.
    /// - Parameter action: A closure to run when the value changes.
    func onChange<T: Equatable>(
        of value: T,
        perform action: @escaping (T, T) -> Void
    ) -> some View {
        modifier(OnChangeViewModifier(content: self, value: value, action: action))
    }
}

struct OnChangeViewModifier<Content: View, T: Equatable>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: Content
    let value: T
    let action: (T, T) -> Void

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        OnChangeModifierViewNode(contentNode: inputs.makeNode(from: content), content: content, currentStoredValue: value, onChangeAction: action)
    }
}

final class OnChangeModifierViewNode<T: Equatable>: ViewModifierNode {
    var currentStoredValue: T
    var onChangeAction: (T, T) -> Void

    init<Content: View>(contentNode: ViewNode, content: Content, currentStoredValue: T, onChangeAction: @escaping (T, T) -> Void) {
        self.currentStoredValue = currentStoredValue
        self.onChangeAction = onChangeAction

        super.init(contentNode: contentNode, content: content)
    }

    override func merge(_ otherNode: ViewNode) {
        super.merge(otherNode)

        guard let node = otherNode as? Self else {
            return
        }

        // Update current stored value and notify about that
        self.onChangeAction = node.onChangeAction

        if node.currentStoredValue != self.currentStoredValue {
            onChangeAction(self.currentStoredValue, node.currentStoredValue)
            self.currentStoredValue = node.currentStoredValue
        }
    }
}
