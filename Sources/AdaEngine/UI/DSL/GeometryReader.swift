//
//  GeometryReader.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

// MARK: - Coordinate Space

public enum WidgetCoordinateSpace {
    case local
    case global
    case named(AnyHashable)
}

public protocol WidgetCoordinateSpaceProtocol {
    var coordinateSpace: WidgetCoordinateSpace { get }
}

public struct GlobalWidgetCoordinateSpace: WidgetCoordinateSpaceProtocol {
    public let coordinateSpace: WidgetCoordinateSpace = .global
}

public struct LocalWidgetCoordinateSpace: WidgetCoordinateSpaceProtocol {
    public let coordinateSpace: WidgetCoordinateSpace = .local
}

extension WidgetCoordinateSpaceProtocol where Self == GlobalWidgetCoordinateSpace {
    public static var global: GlobalWidgetCoordinateSpace {
        GlobalWidgetCoordinateSpace()
    }
}

extension WidgetCoordinateSpaceProtocol where Self == LocalWidgetCoordinateSpace {
    public static var local: LocalWidgetCoordinateSpace {
        LocalWidgetCoordinateSpace()
    }
}

extension WidgetCoordinateSpaceProtocol where Self == LocalWidgetCoordinateSpace {
    public static func named<H: Hashable>(_ name: H) -> NamedWidgetCoordinateSpace {
        NamedWidgetCoordinateSpace(name)
    }
}

public struct NamedWidgetCoordinateSpace: Equatable, WidgetCoordinateSpaceProtocol {
    let name: AnyHashable
    public let coordinateSpace: WidgetCoordinateSpace

    init<H: Hashable>(_ name: H) {
        self.name = name
        self.coordinateSpace = .named(AnyHashable(name))
    }

    public static func == (lhs: NamedWidgetCoordinateSpace, rhs: NamedWidgetCoordinateSpace) -> Bool {
        return lhs.name == rhs.name
    }

    public static func named<H: Hashable>(_ name: H) -> NamedWidgetCoordinateSpace {
        NamedWidgetCoordinateSpace(name)
    }
}

// MARK: - Geometry Reader

@MainActor
public struct GeometryProxy {

    let namedCoordinateSpaceContainer: NamedWidgetCoordinateSpaceContainer
    let localFrame: Rect

    public var size: Size {
        return localFrame.size
    }

    public func frame(in coordinateSpace: WidgetCoordinateSpaceProtocol) -> Rect {
        switch coordinateSpace.coordinateSpace {
        case .local:
            return self.localFrame
        case .global:
            return namedCoordinateSpaceContainer.containers[WidgetRootNode.rootCoordinateSpace.name]?.frame ?? .zero
        case .named(let value):
            return namedCoordinateSpaceContainer.containers[value]?.frame ?? .zero
        }
    }
}

public struct GeometryReader<Content: Widget>: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let content: (GeometryProxy) -> Content

    public init(@WidgetBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        GeometryReaderWidgetNode(contentProxy: content, content: self)
    }
}

class GeometryReaderWidgetNode<Content: Widget>: WidgetContainerNode {
    let contentProxy: (GeometryProxy) -> Content

    init<Root: Widget>(contentProxy: @escaping (GeometryProxy) -> Content, content: Root) {
        self.contentProxy = contentProxy
        super.init(content: content, nodes: [])
    }

    override func performLayout() {
        self.invalidateContent()

        for node in self.nodes {
            node.performLayout()
        }
        
        super.performLayout()
    }

    override func invalidateContent() {
        let context = WidgetNodeBuilderContext(environment: self.environment)
        let proxy = GeometryProxy(
            namedCoordinateSpaceContainer: self.environment.coordinateSpaces,
            localFrame: self.frame
        )
        let content = self.contentProxy(proxy)
        guard let node = WidgetNodeBuilderUtils.findNodeBuilder(in: content) else {
            fatalError()
        }

        let contentNode = node.makeWidgetNode(context: context)
        contentNode.parent = self
        self.nodes = [contentNode]
    }
}

// MARK: - Environment

class NamedWidgetCoordinateSpaceContainer {
    var containers: [AnyHashable: WidgetNode] = [:]
}

struct GeometryReaderNameEnvironmentKey: WidgetEnvironmentKey {
    static var defaultValue = NamedWidgetCoordinateSpaceContainer()
}

extension WidgetEnvironmentValues {
    var coordinateSpaces: NamedWidgetCoordinateSpaceContainer {
        get {
            self[GeometryReaderNameEnvironmentKey.self]
        }
        set {
            self[GeometryReaderNameEnvironmentKey.self] = newValue
        }
    }
}

public extension Widget {
    func coordinateSpace(_ named: NamedWidgetCoordinateSpace) -> some Widget {
        self.modifier(CoordinateSpaceWidgetModifier(named: named, content: self))
    }
}

struct CoordinateSpaceWidgetModifier<Content: Widget>: WidgetModifier, WidgetNodeBuilder {
    typealias Body = Never

    let named: NamedWidgetCoordinateSpace
    let content: Content

    func makeWidgetNode(context: Context) -> WidgetNode {
        CoordinateSpaceWidgetNode(named: named, content: content, context: context)
    }
}

class CoordinateSpaceWidgetNode: WidgetModifierNode {
    init<Content>(
        named: NamedWidgetCoordinateSpace,
        content: Content,
        context: WidgetNodeBuilderContext
    ) where Content : Widget {
        super.init(content: content, nodes: [])
        context.environment.coordinateSpaces.containers[named.name] = self
        self.updateEnvironment(context.environment)
        self.invalidateContent()
    }
}
