//
//  FrameModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

public extension Widget {
    func frame(width: Float? = nil, height: Float? = nil) -> some Widget {
        self.modifier(FrameWidgetModifier(frame: .size(width: width, height: height)))
    }
}

struct FrameWidget<Content: Widget>: Widget, WidgetNodeBuilder {
    
    let frame: FrameWidgetModifier.Frame
    let content: Content
    
    var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        FrameWidgetNode(frameRule: frame, content: self) {
            [context.makeNode(from: content)]
        }
    }
}

struct FrameWidgetModifier: WidgetModifier {
    
    enum Frame {
        case size(width: Float?, height: Float?)
    }
    
    let frame: Frame
    
    func body(content: Content) -> some Widget {
        FrameWidget(frame: frame, content: content)
    }
}

class ModifierWidgetNode: WidgetContainerNode {
    override func performLayout() {
        for node in self.nodes {
            node.frame = self.frame
            node.performLayout()
        }
    }
}

class FrameWidgetNode: ModifierWidgetNode {

    let frameRule: FrameWidgetModifier.Frame

    init(frameRule: FrameWidgetModifier.Frame, content: any Widget, buildNodesBlock: @escaping WidgetContainerNode.BuildContentBlock) {
        self.frameRule = frameRule
        super.init(content: content, buildNodesBlock: buildNodesBlock)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize, usedByParent: Bool = false) -> Size {
        var newSize = Size.zero

        switch frameRule {
        case .size(let width, let height):
            if let width, width > 0 {
                newSize.width = min(width, proposal.width ?? 0)
            } else {
                newSize.width = proposal.width ?? 0
            }

            if let height, height > 0 {
                newSize.height = min(height, proposal.height ?? 0)
            } else {
                newSize.height = proposal.height ?? 0
            }
        }

        return newSize
    }
}

// MARK: - Visibility

public extension Widget {
    func onAppear(perform: @escaping () -> Void) -> some Widget {
        OnAppearWidget(content: self, onAppear: perform)
    }
    
    func onDisappear(perform: @escaping () -> Void) -> some Widget {
        OnDisappearWidget(content: self, onDisappear: perform)
    }
}

struct OnAppearWidget<Content: Widget>: Widget, WidgetNodeBuilder {
    
    let content: Content
    let onAppear: () -> Void
    
    init(content: Content, onAppear: @escaping () -> Void) {
        self.content = content
        self.onAppear = onAppear
    }
    
    var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = WidgetNodeVisibility(content: content)
        node.onAppear = self.onAppear
        return node
    }
    
}

struct OnDisappearWidget<Content: Widget>: Widget, WidgetNodeBuilder {
    
    let content: Content
    let onDisappear: () -> Void
    
    init(content: Content, onDisappear: @escaping () -> Void) {
        self.content = content
        self.onDisappear = onDisappear
    }
    
    var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        let node = WidgetNodeVisibility(content: content)
        node.onDisappear = self.onDisappear
        return node
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
    
    let content: Content
    let backgroundContent: WidgetBackgroundContent
    
    init(content: Content, backgroundContent: WidgetBackgroundContent) {
        self.content = content
        self.backgroundContent = backgroundContent
    }
    
    var body: Never {
        fatalError()
    }
    
    func makeWidgetNode(context: Context) -> WidgetNode {
        return WidgetNodeVisibility(content: content)
    }
}

@MainActor
class CanvasWidgetNode: WidgetNode {

    typealias RenderBlock = (GUIRenderContext, Rect) -> Void

    let drawBlock: RenderBlock

    init(content: any Widget, drawBlock: @escaping RenderBlock) {
        self.drawBlock = drawBlock
        super.init(content: content)
    }

    override func draw(with context: GUIRenderContext) {
        self.drawBlock(context, self.frame)
    }
}

// MARK: - Modify Environment

public extension Widget {
    func transformWidgetContext<Value>(
        _ keyPath: WritableKeyPath<WidgetContextValues, Value>,
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

    let content: Content
    let keyPath: WritableKeyPath<WidgetContextValues, Value>
    let block: (inout Value) -> Void

    var body: Never {
        fatalError()
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        var widgetContext = context.widgetContext
        block(&widgetContext[keyPath: keyPath])

        let newContext = Context(widgetContext: widgetContext)
        if let node = WidgetNodeBuilderFinder.findBuilder(in: content)?.makeWidgetNode(context: newContext) {
            return node
        } else {
            fatalError()
        }
    }
}

@MainActor
enum WidgetNodeBuilderFinder {
    static func findBuilder(in content: any Widget) -> WidgetNodeBuilder? {
        var nodeBuilder: WidgetNodeBuilder? = (content as? WidgetNodeBuilder)

        var body: any Widget = content
        while nodeBuilder == nil {
            let newBody = body.body

            if let builder = newBody as? WidgetNodeBuilder {
                nodeBuilder = builder
                break
            } else {
                body = newBody
            }
        }

        return nodeBuilder
    }
}
