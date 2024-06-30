//
//  VisibilityViewModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public extension View {
    func onAppear(perform: (() -> Void)? = nil) -> some View {
        self.modifier(OnAppearView(content: self, onAppear: perform))
    }

    func onDisappear(perform: (() -> Void)? = nil) -> some View {
        self.modifier(OnDisappearView(content: self, onDisappear: perform))
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

final class VisibilityViewNode: ViewModifierNode {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?

    deinit {
        self.onDisappear?()
    }

    override func performLayout() {
        super.performLayout()

        guard let parent else {
            return
        }
        
        let parentId = parent.id
        var isAppeared = parent.environment.nodeVisibilityHolder.isAppeared[parentId] ?? false

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

        parent.environment.nodeVisibilityHolder.isAppeared[parentId] = isAppeared
        self.updateEnvironment(parent.environment)
    }
}

class ViewNodeVisibilityHolder {
    var isAppeared: [ObjectIdentifier: Bool] = [:]
}

struct ViewNodeVisibilityKey: ViewEnvironmentKey {
    static var defaultValue: ViewNodeVisibilityHolder = ViewNodeVisibilityHolder()
}

fileprivate extension ViewEnvironmentValues {
    var nodeVisibilityHolder: ViewNodeVisibilityHolder {
        get {
            self[ViewNodeVisibilityKey.self]
        }
        set {
            self[ViewNodeVisibilityKey.self] = newValue
        }
    }
}
