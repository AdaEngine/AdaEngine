//
//  NavigationDestination.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import AdaUtils
import Math

public extension View {
    /// Associates a destination view with a presented data type for use within
    /// a navigation stack.
    ///
    /// Add this modifier to a view inside a ``NavigationStack`` to describe the view
    /// that the stack displays when presenting a particular kind of data.
    ///
    /// ```swift
    /// NavigationStack {
    ///     ContentView()
    ///         .navigate(for: String.self) { value in
    ///             DetailView(message: value)
    ///         }
    /// }
    /// ```
    func navigate<D: Hashable, Destination: View>(
        for type: D.Type,
        @ViewBuilder destination: @escaping (D) -> Destination
    ) -> some View {
        modifier(NavigationDestinationModifier(content: self, type: type, destination: destination))
    }
}

struct NavigationDestinationModifier<WrappedContent: View, D: Hashable, Destination: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: WrappedContent
    let type: D.Type
    let destination: (D) -> Destination

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let contentNode = context.makeNode(from: content)
        let node = NavigationDestinationNode(
            contentNode: contentNode,
            content: content,
            type: type,
            destination: destination,
            inputs: context
        )
        return node
    }
}

final class NavigationDestinationNode<D: Hashable, Destination: View>: ViewModifierNode {

    private let type: D.Type
    private let destination: (D) -> Destination
    private var viewInputs: _ViewInputs

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        type: D.Type,
        destination: @escaping (D) -> Destination,
        inputs: _ViewInputs
    ) {
        self.type = type
        self.destination = destination
        self.viewInputs = inputs
        super.init(contentNode: contentNode, content: content)
        registerDestination(in: inputs.environment)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        super.updateEnvironment(environment)
        viewInputs.environment = environment
        registerDestination(in: environment)
    }

    private func registerDestination(in environment: EnvironmentValues) {
        guard let context = environment.navigationContext else { return }
        context.registerDestination(for: type) { [destination] (value: D, inputs: _ViewInputs) -> ViewNode in
            let view = destination(value)
            return Destination._makeView(_ViewGraphNode(value: view), inputs: inputs).node
        }
    }
}
