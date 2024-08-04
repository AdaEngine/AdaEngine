//
//  GeometryReader.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

// MARK: - Coordinate Space

public enum ViewCoordinateSpace {
    case local
    case global
    case scrollView
    case named(AnyHashable)

    internal static let scrollViewId = "_ScrollView"
}

public protocol ViewCoordinateSpaceProtocol {
    var coordinateSpace: ViewCoordinateSpace { get }
}

public struct GlobalViewCoordinateSpace: ViewCoordinateSpaceProtocol {
    public let coordinateSpace: ViewCoordinateSpace = .global
}

public struct LocalViewCoordinateSpace: ViewCoordinateSpaceProtocol {
    public let coordinateSpace: ViewCoordinateSpace = .local
}

extension ViewCoordinateSpaceProtocol where Self == GlobalViewCoordinateSpace {
    public static var global: GlobalViewCoordinateSpace {
        GlobalViewCoordinateSpace()
    }
}

extension ViewCoordinateSpaceProtocol where Self == LocalViewCoordinateSpace {
    public static var local: LocalViewCoordinateSpace {
        LocalViewCoordinateSpace()
    }
}

extension ViewCoordinateSpaceProtocol where Self == LocalViewCoordinateSpace {
    public static func named<H: Hashable>(_ name: H) -> NamedViewCoordinateSpace {
        NamedViewCoordinateSpace(name)
    }
}

public struct NamedViewCoordinateSpace: Equatable, ViewCoordinateSpaceProtocol {
    let name: AnyHashable
    public let coordinateSpace: ViewCoordinateSpace

    init<H: Hashable>(_ name: H) {
        self.name = name
        self.coordinateSpace = .named(AnyHashable(name))
    }

    public static func == (lhs: NamedViewCoordinateSpace, rhs: NamedViewCoordinateSpace) -> Bool {
        return lhs.name == rhs.name
    }

    public static func named<H: Hashable>(_ name: H) -> NamedViewCoordinateSpace {
        NamedViewCoordinateSpace(name)
    }
}

// MARK: - Geometry Reader

@MainActor
public struct GeometryProxy {

    let namedCoordinateSpaceContainer: NamedViewCoordinateSpaceContainer
    let localFrame: Rect

    public var size: Size {
        return localFrame.size
    }

    public func frame(in coordinateSpace: ViewCoordinateSpaceProtocol) -> Rect {
        switch coordinateSpace.coordinateSpace {
        case .local:
            return self.localFrame
        case .global:
            return namedCoordinateSpaceContainer.containers[ViewRootNode.rootCoordinateSpace.name]?.frame ?? .zero
        case .scrollView:
            return namedCoordinateSpaceContainer.containers[ViewCoordinateSpace.scrollViewId]?.frame ?? .zero
        case .named(let value):
            return namedCoordinateSpaceContainer.containers[value]?.frame ?? .zero
        }
    }
}

public struct GeometryReader<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        GeometryReaderViewNode(contentProxy: content, content: self)
    }
}

class GeometryReaderViewNode<Content: View>: ViewContainerNode {
    let contentProxy: (GeometryProxy) -> Content

    init<Root: View>(contentProxy: @escaping (GeometryProxy) -> Content, content: Root) {
        self.contentProxy = contentProxy
        super.init(content: content, body: { _ in fatalError() })
    }

    override func performLayout() {
        self.invalidateContent()

        for node in self.nodes {
            node.performLayout()
        }
        
        super.performLayout()
    }

    override func invalidateContent() {
        let context = _ViewInputs(parentNode: self, environment: self.environment)
        let proxy = GeometryProxy(
            namedCoordinateSpaceContainer: self.environment.coordinateSpaces,
            localFrame: self.frame
        )
        let content = self.contentProxy(proxy)
        let outputs = Content._makeListView(_ViewGraphNode(value: content), inputs: _ViewListInputs(input: context)).outputs
        let nodes = outputs.map { $0.node }

        for node in nodes {
            node.parent = self
        }

        self.nodes = nodes
    }
}

// MARK: - Environment

class NamedViewCoordinateSpaceContainer {
    var containers: [AnyHashable: ViewNode] = [:]
}

extension EnvironmentValues {
    @Entry var coordinateSpaces: NamedViewCoordinateSpaceContainer = NamedViewCoordinateSpaceContainer()
}

public extension View {
    func coordinateSpace(_ named: NamedViewCoordinateSpace) -> some View {
        self.modifier(CoordinateSpaceViewModifier(named: named, content: self))
    }
}

struct CoordinateSpaceViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let named: NamedViewCoordinateSpace
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = context.makeNode(from: content)

        if node is ScrollViewNode {
            context.environment.coordinateSpaces.containers[ViewCoordinateSpace.scrollViewId] = node
        }

        context.environment.coordinateSpaces.containers[named.name] = node
        return ViewModifierNode(contentNode: node, content: content)
    }
}
