//
//  ButtonStyle.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import AdaUtils
import Math

/// A protocol that defines a button style.
@_typeEraser(AnyButtonStyle)
@MainActor public protocol ButtonStyle: Sendable {
    /// The body of the button style.
    associatedtype Body: View

    /// The configuration of the button style.
    typealias Configuration = ButtonStyleConfiguration

    /// Make the body of the button style.
    ///
    /// - Parameter configuration: The configuration of the button style.
    /// - Returns: The body of the button style.
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

/// The properties of a button.
public struct ButtonStyleConfiguration {

    /// The label of the button style.
    public struct Label: View {
        /// The body of the label.
        public typealias Body = Never
        public var body: Never { fatalError() }

        /// The storage of the label.
        enum Storage {
            case makeView((_ViewInputs) -> _ViewOutputs)
            case makeViewList((_ViewListInputs) -> _ViewListOutputs)
        }

        /// The storage of the label.
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
    }

    /// A view that describes the effect of pressing the button.
    public let label: Label

    /// The state of the button style.
    public let state: Button.State

    /// A Boolean value indicating whether the control is in the selected state.
    public var isSelected: Bool {
        state.contains(.selected)
    }

    /// A Boolean value indicating whether the control draws a highlight.
    public var isHighlighted: Bool {
        state.contains(.highlighted)
    }
}

public extension View {

    /// Sets the style for buttons within this view to a button style with a custom appearance and standard interaction behavior.
    ///
    /// - Parameter style: The button style to apply.
    /// - Returns: The view with the button style applied.
    func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        self.environment(\.buttonStyle, style)
    }
}

/// The default button style, based on the button’s context.
public struct DefaultButtonStyle: ButtonStyle {

    /// Initialize a new default button style.
    public init() {}

    /// Make the body of the default button style.
    ///
    /// - Parameter configuration: The configuration of the default button style.
    /// - Returns: The body of the default button style.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ButtonEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ButtonStyle = DefaultButtonStyle()
}

extension EnvironmentValues {
    var buttonStyle: any ButtonStyle {
        get { return self[ButtonEnvironmentKey.self] }
        set { self[ButtonEnvironmentKey.self] = newValue }
    }
}

/// A type-erased button style.
public struct AnyButtonStyle: ButtonStyle {

    /// The style of the type-erased button style.
    let style: any ButtonStyle

    /// Initialize a new type-erased button style.
    ///
    /// - Parameter style: The style to erase.
    public init<S: ButtonStyle>(erasing style: S) {
        self.style = style
    }

    /// Make the body of the type-erased button style.
    ///
    /// - Parameter configuration: The configuration of the type-erased button style.
    /// - Returns: The body of the type-erased button style.
    public func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}
