//
//  ButtonStyle.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import Math

@_typeEraser(AnyButtonStyle)
@MainActor public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration

    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

public struct ButtonStyleConfiguration {

    public struct Label: View {
        public typealias Body = Never
        public var body: Never { fatalError() }

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
    }

    public let label: Label
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
    func buttonStyle<S: ButtonStyle>(_ style: S) -> some View {
        self.environment(\.buttonStyle, style)
    }
}

/// The default button style, based on the button’s context.
public struct DefaultButtonStyle: ButtonStyle {

    public nonisolated init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ButtonEnvironmentKey: EnvironmentKey {
    @MainActor static var defaultValue: any ButtonStyle = DefaultButtonStyle()
}

extension EnvironmentValues {
    var buttonStyle: any ButtonStyle {
        get { return self[ButtonEnvironmentKey.self] }
        set { self[ButtonEnvironmentKey.self] = newValue }
    }
}

public struct AnyButtonStyle: ButtonStyle {
    
    let style: any ButtonStyle

    public init<S: ButtonStyle>(erasing style: S) {
        self.style = style
    }

    public func makeBody(configuration: Configuration) -> AnyView {
        AnyView(style.makeBody(configuration: configuration))
    }
}
