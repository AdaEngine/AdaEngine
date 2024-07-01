//
//  Button.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import Math

public struct Button: View, ViewNodeBuilder {

    public struct State: OptionSet, Hashable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// A Boolean value indicating whether the control is in the enabled state.
        public var isEnabled: Bool {
            !self.contains(.disabled)
        }

        /// A Boolean value indicating whether the control is in the selected state.
        public var isSelected: Bool {
            self.contains(.selected)
        }

        /// A Boolean value indicating whether the control draws a highlight.
        public var isHighlighted: Bool {
            self.contains(.highlighted)
        }

        public static let normal = State(rawValue: 1 << 0)
        public static let disabled = State(rawValue: 1 << 1)
        public static let highlighted = State(rawValue: 1 << 2)
        public static let focused = State(rawValue: 1 << 3)
        public static let selected = State(rawValue: 1 << 4)
    }

    public typealias Body = Never

    let action: () -> Void
    let label: ButtonStyleConfiguration.Label.Storage

    public init<Label: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        let label = label()
        self.label = .makeView({ Label._makeView(_ViewGraphNode(value: label), inputs: $0) })
    }

    public init(_ text: String, action: @escaping () -> Void) {
        self.action = action
        self.label = .makeView({ Text._makeView(_ViewGraphNode(value: Text(text)), inputs: $0) })
    }

    // MARK: - ViewNodeBuilder

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        ButtonViewNode(
            content: self,
            label: label,
            viewInputs: inputs,
            action: self.action
        )
    }
}

final class ButtonViewNode: ViewModifierNode {

    private(set) var action: () -> Void
    private var body: (Button.State) -> ViewNode

    private var state: Button.State = .normal

    init<Content: View>(content: Content, label: ButtonStyleConfiguration.Label.Storage, viewInputs: _ViewInputs, action: @escaping () -> Void) {
        self.action = action
        self.body = { state in
            let configuration = ButtonStyleConfiguration(
                label: ButtonStyleConfiguration.Label(storage: label),
                state: state
            )
            let body = AnyView(viewInputs.environment.buttonStyle.makeBody(configuration: configuration))
            return AnyButtonStyle.Body._makeView(_ViewGraphNode(value: body), inputs: viewInputs).node
        }

        super.init(contentNode: body(.normal), content: content)
    }

    override func invalidateContent() {
        let body = self.body(self.state)
        self.contentNode = body
        self.performLayout()
    }

    override func merge(_ otherNode: ViewNode) {
        guard let otherNode = otherNode as? ButtonViewNode else {
            return
        }

        self.action = otherNode.action
        super.merge(otherNode)
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        contentNode.draw(with: context)
        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }

    // MARK: - Interaction

    override func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        if contentNode.hitTest(point, with: event) != nil {
            return self
        }

        return nil
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if !self.state.isEnabled {
            return
        }

        switch event.phase {
        case .began, .changed:
            switch event.button {
            case .none:
                state.insert(.highlighted)
            case .left:
                state.insert(.selected)
            default:
                return
            }
        case .ended, .cancelled:
            state.remove(.selected)
            state.remove(.focused)
            state.remove(.highlighted)

            self.action()
        }

        self.invalidateContent()
    }
}
