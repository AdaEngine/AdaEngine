//
//  VisibilityViewModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

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

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = VisibilityViewNode(
            contentNode: inputs.makeNode(from: content),
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

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = VisibilityViewNode(
            contentNode: inputs.makeNode(from: content),
            content: content
        )
        node.onDisappear = self.onDisappear
        return node
    }
}

// FIXME: Should use smth like hierarchy ID, because parent id isn't source of truth
final class VisibilityViewNode: ViewModifierNode {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?

    private var identifier = UUID()

    deinit {
        self.onDisappear?()
    }

    var isAppeared = false

    override func merge(_ otherNode: ViewNode) {
        super.merge(otherNode)

        guard let node = otherNode as? VisibilityViewNode else {
            return
        }

        isAppeared = node.isAppeared
    }

    override func performLayout() {
        super.performLayout()

        guard let parent else {
            return
        }

        if parent.frame.intersects(self.frame) {
            if !isAppeared {
                isAppeared = true
                onAppear?()
            }
        } else {
            if isAppeared {
                isAppeared = false
                onDisappear?()
            }
        }
    }
}
