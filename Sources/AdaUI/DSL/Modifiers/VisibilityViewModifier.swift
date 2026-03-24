//
//  VisibilityViewModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

public extension View {
    /// Adds an action to perform before this view appears.
    /// - Parameter action: The action to perform. If action is nil, the call has no effect.
    func onAppear(perform action: (() -> Void)? = nil) -> some View {
        self.modifier(OnAppearView(content: self, onAppear: action))
    }

    /// Adds an action to perform after this view disappears.
    /// - Parameter action: The action to perform. If action is nil, the call has no effect.
    func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        self.modifier(OnDisappearView(content: self, onDisappear: action))
    }
}

struct OnAppearView<Content: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let onAppear: (() -> Void)?

    init(content: Content, onAppear: (() -> Void)? = nil) {
        self.content = content
        self.onAppear = onAppear
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = VisibilityViewNode(
            contentNode: context.makeNode(from: content),
            content: content
        )
        node.onAppear = self.onAppear
        return node
    }
}

struct OnDisappearView<Content: View>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let onDisappear: (() -> Void)?

    init(content: Content, onDisappear: (() -> Void)?) {
        self.content = content
        self.onDisappear = onDisappear
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = VisibilityViewNode(
            contentNode: context.makeNode(from: content),
            content: content
        )
        node.onDisappear = self.onDisappear
        return node
    }
}

/// Handle visibility view on the screen.
final class VisibilityViewNode: ViewModifierNode {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?

    private var isAppeared = false

    override func updateViewOwner(_ owner: ViewOwner) {
        let wasAppeared = isAppeared
        super.updateViewOwner(owner)
        if !wasAppeared {
            isAppeared = true
            onAppear?()
        }
    }

    override func didMove(to parent: ViewNode?) {
        if parent == nil && isAppeared {
            isAppeared = false
            onDisappear?()
        }
        super.didMove(to: parent)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        guard let other = newNode as? VisibilityViewNode else { return }
        self.onAppear = other.onAppear
        self.onDisappear = other.onDisappear
    }
}
