//
//  FrameModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public extension Widget {
    func frame(width: Float? = nil, height: Float? = nil) -> some Widget {
        self.modifier(
            FrameWidgetModifier(
                content: self,
                frame: .size(width: width, height: height)
            )
        )
    }
}

struct FrameWidgetModifier<Content: Widget>: WidgetModifier, WidgetNodeBuilder {

    typealias Body = Never
    let content: Content

    let frame: FrameWidgetNode.Frame

    func makeWidgetNode(context: Context) -> WidgetNode {
        FrameWidgetNode(frameRule: frame, content: content, context: context)
    }
}

final class FrameWidgetNode: WidgetContainerNode {

    enum Frame {
        case size(width: Float?, height: Float?)
    }

    let frameRule: Frame

    init<Content: Widget>(frameRule: Frame, content: Content, context: WidgetNodeBuilderContext) {
        self.frameRule = frameRule
        super.init(content: content, context: context)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        var newSize = super.sizeThatFits(proposal)

        switch frameRule {
        case .size(let width, let height):
            if let width {
                newSize.width = width
            }

            if let height {
                newSize.height = height
            }
        }

        return newSize
    }

    override func performLayout() {
        for node in nodes {
            node.place(in: .zero, anchor: .zero, proposal: ProposedViewSize(self.frame.size))
        }
    }
}

// MARK: - Background

public extension Widget {
    func background(_ color: Color) -> some Widget {
        BackgroundWidget(content: self, backgroundContent: .color(color))
    }
    
    func background<Content: Widget>(@WidgetBuilder _ content: () -> Content) -> some Widget {
        BackgroundWidget(content: self, backgroundContent: .widget(content()))
    }
}

enum WidgetBackgroundContent {
    case color(Color)
    case widget(any Widget)
}

struct BackgroundWidget<Content: Widget>: Widget, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let backgroundContent: WidgetBackgroundContent
    
    init(content: Content, backgroundContent: WidgetBackgroundContent) {
        self.content = content
        self.backgroundContent = backgroundContent
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        return WidgetNodeVisibility(content: content, context: context)
    }
}

// MARK: - Modify Environment

public extension Widget {
    func transformWidgetContext<Value>(
        _ keyPath: WritableKeyPath<WidgetEnvironmentValues, Value>,
        block: @escaping (inout Value) -> Void
    ) -> some Widget {
        TransformWidgetContextModifier(
            content: self,
            keyPath: keyPath,
            block: block
        )
    }
}

struct TransformWidgetContextModifier<Content: Widget, Value>: Widget, WidgetNodeBuilder {

    typealias Body = Never

    let content: Content
    let keyPath: WritableKeyPath<WidgetEnvironmentValues, Value>
    let block: (inout Value) -> Void

    func makeWidgetNode(context: Context) -> WidgetNode {
        var environment = context.environment
        block(&environment[keyPath: keyPath])

        let newContext = Context(environment: environment)
        if let node = WidgetNodeBuilderUtils.findNodeBuilder(in: content)?.makeWidgetNode(context: newContext) {
            return node
        } else {
            fatalError("Fail to find builder")
        }
    }
}
