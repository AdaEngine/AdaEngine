//
//  AlertModifier.swift
//  AdaEngine
//
//  Created by Codex on 29.04.2026.
//

import AdaText

public extension View {
    /// Presents an alert when a given condition is true.
    func alert<S, Actions, Message>(
        _ title: S,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder message: @escaping () -> Message
    ) -> some View where S: StringProtocol, Actions: View, Message: View {
        modifier(
            AlertViewModifier(
                content: self,
                title: String(title),
                isPresented: isPresented,
                data: EmptyAlertPresentationData(),
                actions: { _ in actions() },
                message: { _ in message() }
            )
        )
    }

    /// Presents an alert when a given condition is true.
    func alert<S, Actions>(
        _ title: S,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View where S: StringProtocol, Actions: View {
        alert(title, isPresented: isPresented, actions: actions, message: EmptyView.init)
    }

    /// Presents an alert with a default OK action when a given condition is true.
    func alert<S>(
        _ title: S,
        isPresented: Binding<Bool>
    ) -> some View where S: StringProtocol {
        alert(title, isPresented: isPresented, actions: EmptyView.init, message: EmptyView.init)
    }

    /// Presents an alert using the given data to produce the alert's content.
    func alert<S, Data, Actions, Message>(
        _ title: S,
        isPresented: Binding<Bool>,
        presenting data: Data?,
        @ViewBuilder actions: @escaping (Data) -> Actions,
        @ViewBuilder message: @escaping (Data) -> Message
    ) -> some View where S: StringProtocol, Actions: View, Message: View {
        modifier(
            AlertViewModifier(
                content: self,
                title: String(title),
                isPresented: isPresented,
                data: data,
                actions: actions,
                message: message
            )
        )
    }

    /// Presents an alert using the given data to produce the alert's actions.
    func alert<S, Data, Actions>(
        _ title: S,
        isPresented: Binding<Bool>,
        presenting data: Data?,
        @ViewBuilder actions: @escaping (Data) -> Actions
    ) -> some View where S: StringProtocol, Actions: View {
        alert(title, isPresented: isPresented, presenting: data, actions: actions, message: { _ in EmptyView() })
    }
}

@_spi(Internal)
public struct AlertPresentation {
    public struct Button {
        public enum Role {
            case cancel
            case destructive
        }

        public let title: String
        public let role: Role?
        public let action: (() -> Void)?

        public init(title: String, role: Role? = nil, action: (() -> Void)? = nil) {
            self.title = title
            self.role = role
            self.action = action
        }
    }

    public let title: String
    public let message: String?
    public let buttons: [Button]

    public init(title: String, message: String?, buttons: [Button]) {
        self.title = title
        self.message = message
        self.buttons = buttons
    }
}

@_spi(Internal)
@MainActor
public enum AlertPresentationCenter {
    public static var showAlert: ((AlertPresentation) -> Void)?
}

private struct EmptyAlertPresentationData {}

private struct AlertViewModifier<WrappedContent: View, Data, Actions: View, Message: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: WrappedContent
    let title: String
    let isPresented: Binding<Bool>
    let data: Data?
    let actions: (Data) -> Actions
    let message: (Data) -> Message

    func buildViewNode(in context: BuildContext) -> ViewNode {
        AlertModifierNode(
            contentNode: context.makeNode(from: content),
            content: content,
            title: title,
            isPresented: isPresented,
            data: data,
            actions: actions,
            message: message
        )
    }
}

private final class AlertModifierNode<Data, Actions: View, Message: View>: ViewModifierNode {
    private var title: String
    private var isPresented: Binding<Bool>
    private var data: Data?
    private var actions: (Data) -> Actions
    private var message: (Data) -> Message
    private var hasPresented = false

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        title: String,
        isPresented: Binding<Bool>,
        data: Data?,
        actions: @escaping (Data) -> Actions,
        message: @escaping (Data) -> Message
    ) {
        self.title = title
        self.isPresented = isPresented
        self.data = data
        self.actions = actions
        self.message = message
        super.init(contentNode: contentNode, content: content)
        presentIfNeeded()
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? AlertModifierNode<Data, Actions, Message> else { return }

        self.title = other.title
        self.isPresented = other.isPresented
        self.data = other.data
        self.actions = other.actions
        self.message = other.message
        presentIfNeeded()
    }

    private func presentIfNeeded() {
        guard isPresented.wrappedValue else {
            hasPresented = false
            return
        }

        guard !hasPresented, let data else {
            return
        }

        hasPresented = true

        let actionButtons = actions(data).alertButtons
        let buttons = (actionButtons.isEmpty ? [.init(title: "OK", role: .cancel, action: nil)] : actionButtons).map { button in
            AlertPresentation.Button(
                title: button.title,
                role: button.role,
                action: { [isPresented] in
                    isPresented.wrappedValue = false
                    button.action?()
                }
            )
        }

        let presentation = AlertPresentation(
            title: title,
            message: message(data).alertMessage,
            buttons: buttons
        )
        AlertPresentationCenter.showAlert?(presentation)

        if !isPresented.wrappedValue {
            hasPresented = false
        }
    }
}

private struct AlertButtonDescription {
    let title: String
    let role: AlertPresentation.Button.Role?
    let action: (() -> Void)?
}

@MainActor
private protocol AlertActionsConvertible {
    var alertButtons: [AlertButtonDescription] { get }
}

@MainActor
private protocol AlertMessageConvertible {
    var alertMessage: String? { get }
}

private extension View {
    var alertButtons: [AlertButtonDescription] {
        (self as? AlertActionsConvertible)?.alertButtons ?? []
    }

    var alertMessage: String? {
        (self as? AlertMessageConvertible)?.alertMessage
    }
}

@MainActor
extension Button: AlertActionsConvertible {
    fileprivate var alertButtons: [AlertButtonDescription] {
        guard let title = alertTitle else {
            return []
        }

        return [
            AlertButtonDescription(
                title: title,
                role: role?.alertRole,
                action: action
            )
        ]
    }
}

extension ButtonRole {
    fileprivate var alertRole: AlertPresentation.Button.Role {
        switch storage {
        case .cancel:
            return .cancel
        case .destructive:
            return .destructive
        }
    }
}

@MainActor
extension EmptyView: AlertActionsConvertible, AlertMessageConvertible {
    fileprivate var alertButtons: [AlertButtonDescription] {
        []
    }

    fileprivate var alertMessage: String? {
        nil
    }
}

@MainActor
extension Optional: AlertActionsConvertible where Wrapped: View {
    fileprivate var alertButtons: [AlertButtonDescription] {
        switch self {
        case .some(let wrapped):
            return wrapped.alertButtons
        case .none:
            return []
        }
    }
}

@MainActor
extension Optional: AlertMessageConvertible where Wrapped: View {
    fileprivate var alertMessage: String? {
        switch self {
        case .some(let wrapped):
            return wrapped.alertMessage
        case .none:
            return nil
        }
    }
}

@MainActor
extension ViewTuple: AlertActionsConvertible {
    fileprivate var alertButtons: [AlertButtonDescription] {
        Mirror(reflecting: value).children.flatMap { child in
            (child.value as? AlertActionsConvertible)?.alertButtons ?? []
        }
    }
}

@MainActor
extension ViewTuple: AlertMessageConvertible {
    fileprivate var alertMessage: String? {
        Mirror(reflecting: value).children.compactMap { child in
            (child.value as? AlertMessageConvertible)?.alertMessage
        }.joined(separator: "\n")
    }
}

@MainActor
extension _ConditionalContent: AlertActionsConvertible where TrueContent: View, FalseContent: View {
    fileprivate var alertButtons: [AlertButtonDescription] {
        switch storage {
        case .trueContent(let content):
            return content.alertButtons
        case .falseContent(let content):
            return content.alertButtons
        }
    }
}

@MainActor
extension _ConditionalContent: AlertMessageConvertible where TrueContent: View, FalseContent: View {
    fileprivate var alertMessage: String? {
        switch storage {
        case .trueContent(let content):
            return content.alertMessage
        case .falseContent(let content):
            return content.alertMessage
        }
    }
}

@MainActor
extension AnyView: AlertActionsConvertible {
    fileprivate var alertButtons: [AlertButtonDescription] {
        content.alertButtons
    }
}

@MainActor
extension AnyView: AlertMessageConvertible {
    fileprivate var alertMessage: String? {
        content.alertMessage
    }
}

@MainActor
extension Text: AlertMessageConvertible {
    fileprivate var alertMessage: String? {
        plainText
    }
}

extension Text {
    var plainText: String {
        storage.text.text
    }
}
