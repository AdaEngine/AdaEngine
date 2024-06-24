//
//  VisibilityWidgetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public extension Widget {
    func onAppear(perform: (() -> Void)? = nil) -> some Widget {
        self.modifier(OnAppearWidget(content: self, onAppear: perform))
    }

    func onDisappear(perform: (() -> Void)? = nil) -> some Widget {
        self.modifier(OnDisappearWidget(content: self, onDisappear: perform))
    }
}

struct OnAppearWidget<Content: Widget>: WidgetModifier, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let onAppear: (() -> Void)?

    init(content: Content, onAppear: (() -> Void)? = nil) {
        self.content = content
        self.onAppear = onAppear
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = WidgetNodeVisibility(content: content, context: context)
        node.onAppear = self.onAppear
        return node
    }
}

struct OnDisappearWidget<Content: Widget>: WidgetModifier, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let onDisappear: (() -> Void)?

    init(content: Content, onDisappear: (() -> Void)?) {
        self.content = content
        self.onDisappear = onDisappear
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = WidgetNodeVisibility(content: content, context: context)
        node.onDisappear = self.onDisappear
        return node
    }
}

class WidgetNodeVisibility: WidgetContainerNode {
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

        if parent.frame.intersects(self.frame) {
            self.onAppear?()
        } else {
            self.onDisappear?()
        }
    }
}
