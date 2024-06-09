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
        RectangleWidgetNode(rect: .zero, stackIndex: 0, content: content)
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
        let node = WidgetNodeVisibility(stackIndex: 0, content: content)
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
        let node = WidgetNodeVisibility(stackIndex: 0, content: content)
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
        let node = WidgetNodeVisibility(stackIndex: 0, content: content)
        return node
    }
    
}
