//
//  ContextMenuModifier.swift
//  AdaEngine
//
//  Created by Codex on 29.04.2026.
//

import AdaInput
import AdaUtils
import Math

public extension View {
    /// Presents a context menu when the view receives a secondary click or a long press.
    func contextMenu<MenuItems: View>(
        onPresent: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder menuItems: @escaping () -> MenuItems
    ) -> some View {
        modifier(
            ContextMenuViewModifier(
                content: self,
                minimumPressDuration: 0.75,
                onPresent: onPresent,
                onDismiss: onDismiss,
                menuItems: menuItems
            )
        )
    }
}

@_spi(Internal)
public struct ContextMenuPresentation {
    public struct Item: Identifiable {
        public enum Role {
            case destructive
        }

        public let id: Int
        public let title: String
        public let role: Role?
        public let action: (() -> Void)?
        public let submenu: [Item]
        public let isSeparator: Bool

        public init(
            id: Int,
            title: String,
            role: Role? = nil,
            action: (() -> Void)? = nil,
            submenu: [Item] = [],
            isSeparator: Bool = false
        ) {
            self.id = id
            self.title = title
            self.role = role
            self.action = action
            self.submenu = submenu
            self.isSeparator = isSeparator
        }
    }

    public let sourceWindow: UIWindow?
    public let location: Point
    public let items: [Item]
    public let onDismiss: (() -> Void)?

    public init(sourceWindow: UIWindow?, location: Point, items: [Item], onDismiss: (() -> Void)? = nil) {
        self.sourceWindow = sourceWindow
        self.location = location
        self.items = items
        self.onDismiss = onDismiss
    }
}

@_spi(Internal)
@MainActor
public enum ContextMenuPresentationCenter {
    public static var present: ((ContextMenuPresentation) -> Void)?
    public static var dismissAll: (() -> Bool)?
    public static var dismissForInteraction: ((UIWindow?) -> Void)?
    public static var dismissForDeactivation: ((UIWindow?) -> Void)?
}

/// A submenu entry for ``View/contextMenu(menuItems:)``.
public struct ContextMenuSubmenu<MenuItems: View>: View {
    public typealias Body = Never
    public var body: Never { fatalError() }

    let title: String
    let menuItems: () -> MenuItems

    public init(_ title: String, @ViewBuilder menuItems: @escaping () -> MenuItems) {
        self.title = title
        self.menuItems = menuItems
    }
}

private struct ContextMenuViewModifier<WrappedContent: View, MenuItems: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let content: WrappedContent
    let minimumPressDuration: TimeInterval
    let onPresent: (() -> Void)?
    let onDismiss: (() -> Void)?
    let menuItems: () -> MenuItems

    func buildViewNode(in context: BuildContext) -> ViewNode {
        ContextMenuModifierNode(
            contentNode: context.makeNode(from: content),
            content: content,
            minimumPressDuration: minimumPressDuration,
            onPresent: onPresent,
            onDismiss: onDismiss,
            menuItems: menuItems
        )
    }
}

private final class ContextMenuModifierNode<MenuItems: View>: ViewModifierNode {
    private let minimumPressDuration: TimeInterval
    private var onPresent: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var menuItems: () -> MenuItems
    private var pressStartLocation: Point?
    private var pressLocation: Point?
    private var lastPressMouseEvent: MouseEvent?
    private var lastPressTouches: Set<TouchEvent>?
    private weak var activeContentEventNode: ViewNode?
    private var elapsedPressDuration: TimeInterval = 0
    private var didPresentForCurrentPress = false

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        minimumPressDuration: TimeInterval,
        onPresent: (() -> Void)?,
        onDismiss: (() -> Void)?,
        menuItems: @escaping () -> MenuItems
    ) {
        self.minimumPressDuration = minimumPressDuration
        self.onPresent = onPresent
        self.onDismiss = onDismiss
        self.menuItems = menuItems
        super.init(contentNode: contentNode, content: content)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }

        if let mouseEvent = event as? MouseEvent {
            if mouseEvent.button == .right {
                return self
            }

            if mouseEvent.button == .left, mouseEvent.phase == .began {
                activeContentEventNode = super.hitTest(point, with: event)
                return self
            }

            return super.hitTest(point, with: event)
        }

        if let touchEvent = event as? TouchEvent, touchEvent.phase == .began {
            activeContentEventNode = super.hitTest(point, with: event)
        }
        return self
    }

    override func onMouseEvent(_ event: MouseEvent) {
        switch event.phase {
        case .began:
            if event.button == .right {
                present(at: event.mousePosition)
                resetPressTracking()
                return
            }

            if event.button == .left {
                lastPressMouseEvent = event
                lastPressTouches = nil
                startPressTracking(at: event.mousePosition)
            }
        case .changed:
            if pressStartLocation != nil {
                pressLocation = event.mousePosition
            }
        case .ended, .cancelled:
            break
        }

        activeContentEventNode?.onMouseEvent(event)

        if event.phase == .ended || event.phase == .cancelled {
            resetPressTracking()
        }
    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        guard let touch = touches.first else {
            contentNode.onTouchesEvent(touches)
            return
        }

        switch touch.phase {
        case .began:
            lastPressMouseEvent = nil
            lastPressTouches = touches
            startPressTracking(at: touch.location)
        case .moved:
            lastPressTouches = touches
            pressLocation = touch.location
        case .ended, .cancelled:
            break
        }

        activeContentEventNode?.onTouchesEvent(touches)

        if touch.phase == .ended || touch.phase == .cancelled {
            resetPressTracking()
        }
    }

    override func update(_ deltaTime: TimeInterval) {
        if pressStartLocation != nil, !didPresentForCurrentPress {
            elapsedPressDuration += deltaTime
            if elapsedPressDuration >= minimumPressDuration {
                didPresentForCurrentPress = true
                cancelContentPress()
                present(at: pressLocation ?? pressStartLocation ?? .zero)
            }
        }

        super.update(deltaTime)
    }

    override func onMouseLeave() {
        activeContentEventNode?.onMouseLeave()
        resetPressTracking()
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? ContextMenuModifierNode<MenuItems> else { return }
        self.onPresent = other.onPresent
        self.onDismiss = other.onDismiss
        self.menuItems = other.menuItems
    }

    private func startPressTracking(at location: Point) {
        pressStartLocation = location
        pressLocation = location
        elapsedPressDuration = 0
        didPresentForCurrentPress = false
    }

    private func resetPressTracking() {
        pressStartLocation = nil
        pressLocation = nil
        lastPressMouseEvent = nil
        lastPressTouches = nil
        elapsedPressDuration = 0
        didPresentForCurrentPress = false
        activeContentEventNode = nil
    }

    private func cancelContentPress() {
        if let event = lastPressMouseEvent {
            activeContentEventNode?.onMouseEvent(
                MouseEvent(
                    window: event.window,
                    button: .left,
                    mousePosition: pressLocation ?? event.mousePosition,
                    phase: .cancelled,
                    modifierKeys: event.modifierKeys,
                    time: event.time
                )
            )
        }

        if let touches = lastPressTouches {
            let cancelledTouches = Set(
                touches.map { touch in
                    TouchEvent(
                        window: touch.window,
                        location: pressLocation ?? touch.location,
                        phase: .cancelled,
                        time: touch.time
                    )
                }
            )
            activeContentEventNode?.onTouchesEvent(cancelledTouches)
        }
    }

    private func present(at location: Point) {
        let items = menuItems().contextMenuItems
        guard !items.isEmpty else { return }

        onPresent?()
        ContextMenuPresentationCenter.present?(
            ContextMenuPresentation(
                sourceWindow: owner?.window,
                location: location,
                items: items.enumerated().map { index, item in
                    ContextMenuPresentation.Item(
                        id: index,
                        title: item.title,
                        role: item.role,
                        action: item.action,
                        submenu: item.submenu.presentationItems(),
                        isSeparator: item.isSeparator
                    )
                },
                onDismiss: onDismiss
            )
        )
    }
}

private struct ContextMenuItemDescription {
    let title: String
    let role: ContextMenuPresentation.Item.Role?
    let action: (() -> Void)?
    let submenu: [ContextMenuItemDescription]
    let isSeparator: Bool

    init(
        title: String,
        role: ContextMenuPresentation.Item.Role? = nil,
        action: (() -> Void)? = nil,
        submenu: [ContextMenuItemDescription] = [],
        isSeparator: Bool = false
    ) {
        self.title = title
        self.role = role
        self.action = action
        self.submenu = submenu
        self.isSeparator = isSeparator
    }
}

@MainActor
private protocol ContextMenuItemsConvertible {
    var contextMenuItems: [ContextMenuItemDescription] { get }
}

private extension View {
    var contextMenuItems: [ContextMenuItemDescription] {
        (self as? ContextMenuItemsConvertible)?.contextMenuItems ?? []
    }
}

@MainActor
extension Button: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        guard let title = alertTitle else {
            return []
        }

        return [
            ContextMenuItemDescription(
                title: title,
                role: role == .destructive ? .destructive : nil,
                action: action
            )
        ]
    }
}

@MainActor
extension ContextMenuSubmenu: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        [
            ContextMenuItemDescription(
                title: title,
                submenu: menuItems().contextMenuItems
            )
        ]
    }
}

@MainActor
extension EmptyView: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        []
    }
}

@MainActor
extension Divider: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        [ContextMenuItemDescription(title: "", isSeparator: true)]
    }
}

@MainActor
extension Optional: ContextMenuItemsConvertible where Wrapped: View {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        switch self {
        case .some(let wrapped):
            return wrapped.contextMenuItems
        case .none:
            return []
        }
    }
}

@MainActor
extension ViewTuple: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        Mirror(reflecting: value).children.flatMap { child in
            (child.value as? ContextMenuItemsConvertible)?.contextMenuItems ?? []
        }
    }
}

@MainActor
extension _ConditionalContent: ContextMenuItemsConvertible where TrueContent: View, FalseContent: View {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        switch storage {
        case .trueContent(let content):
            return content.contextMenuItems
        case .falseContent(let content):
            return content.contextMenuItems
        }
    }
}

@MainActor
extension AnyView: ContextMenuItemsConvertible {
    fileprivate var contextMenuItems: [ContextMenuItemDescription] {
        content.contextMenuItems
    }
}

private extension [ContextMenuItemDescription] {
    func presentationItems() -> [ContextMenuPresentation.Item] {
        self.enumerated().map { index, item in
            ContextMenuPresentation.Item(
                id: index,
                title: item.title,
                role: item.role,
                action: item.action,
                submenu: item.submenu.presentationItems(),
                isSeparator: item.isSeparator
            )
        }
    }
}
