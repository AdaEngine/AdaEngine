//
//  Button.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import AdaInput
import AdaUtils
import Math

/// A control that initiates an action.
public struct Button: View, ViewNodeBuilder {
    /// A state of the button.
    public struct State: OptionSet, Hashable, Sendable {
        public let rawValue: UInt

        /// Initialize a new state.
        ///
        /// - Parameter rawValue: The raw value of the state.
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

        /// The normal state.
        public static let normal = State(rawValue: 1 << 0)

        /// The disabled state.
        public static let disabled = State(rawValue: 1 << 1)

        /// The highlighted state.
        public static let highlighted = State(rawValue: 1 << 2)

        /// The focused state.
        public static let focused = State(rawValue: 1 << 3)

        /// The selected state.
        public static let selected = State(rawValue: 1 << 4)
    }

    /// The body of the button.
    public typealias Body = Never
    public var body: Never { fatalError() }

    /// The action of the button.
    let action: () -> Void
    let label: ButtonStyleConfiguration.Label.Storage

    /// Initialize a new button.
    ///
    /// - Parameter action: The action of the button.
    /// - Parameter label: The label of the button.
    @MainActor
    public init<Label: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        let label = label()
        self.label = .makeView({ Label._makeView(_ViewGraphNode(value: label), inputs: $0) })
    }

    /// Initialize a new button.
    ///
    /// - Parameter text: The text of the button.
    /// - Parameter action: The action of the button.
    @MainActor
    public init(_ text: String, action: @escaping () -> Void) {
        self.action = action
        self.label = .makeView({ Text._makeView(_ViewGraphNode(value: Text(text)), inputs: $0) })
    }

    // MARK: - ViewNodeBuilder
    
    func buildViewNode(in context: BuildContext) -> ViewNode {
        ButtonViewNode(
            content: self,
            label: label,
            viewInputs: context,
            action: self.action
        )
    }
}

final class ButtonViewNode: ViewModifierNode {

    private(set) var action: () -> Void
    private var body: (Button.State, EnvironmentValues) -> ViewNode

    private var state: Button.State = .normal

    init<Content: View>(content: Content, label: ButtonStyleConfiguration.Label.Storage, viewInputs: _ViewInputs, action: @escaping () -> Void) {
        self.action = action
        self.body = { state, environment in
            let configuration = ButtonStyleConfiguration(
                label: ButtonStyleConfiguration.Label(storage: label),
                state: state
            )

            var viewInputs = viewInputs
            viewInputs.environment = environment
            let inputs = viewInputs.resolveStorages(in: environment.buttonStyle)
            let body = AnyView(environment.buttonStyle.makeBody(configuration: configuration))
            return AnyButtonStyle.Body._makeView(_ViewGraphNode(value: body), inputs: inputs).node
        }

        super.init(contentNode: body(.normal, viewInputs.environment), content: content)
        self.updateEnvironment(viewInputs.environment)
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        super.draw(with: context)
    }

    override func invalidateContent() {
        let body = self.body(self.state, self.environment)
        self.contentNode = body
        self.contentNode.parent = self
        self.performLayout()
    }

    override func performLayout() {
        let proposal = ProposedViewSize(self.frame.size)

        self.contentNode.place(
            in: .zero,
            anchor: .zero,
            proposal: proposal
        )
    }

    override func update(from newNode: ViewNode) {
        guard let otherNode = newNode as? ButtonViewNode else {
            return
        }

        self.action = otherNode.action
        super.update(from: otherNode)
    }

    // MARK: - Interaction

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        if contentNode.hitTest(point, with: event) != nil {
            return self
        }

        return nil
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if !self.state.isEnabled || !self.environment.isEnabled {
            return
        }

        switch event.phase {
        case .began, .changed:
            state.insert(.highlighted)

            switch event.button {
            case .left:
                state.insert(.selected)
                state.remove(.highlighted)
            default:
                break
            }
        case .ended, .cancelled:
            state.remove(.selected)
            state.remove(.focused)
            state.remove(.highlighted)

            self.action()
        }

        self.invalidateContent()
    }

    override func onMouseLeave() {
        state = .normal
        self.invalidateContent()
    }
}
