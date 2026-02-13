//
//  GeometryReader.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaUtils
import Math

// MARK: - Coordinate Space

/// A view coordinate space.
public enum ViewCoordinateSpace {
    /// A local view coordinate space.
    case local
    /// A global view coordinate space.
    case global
    /// A scroll view coordinate space.
    case scrollView
    /// A named view coordinate space.
    case named(AnyHashable)

    /// The scroll view id.
    internal static let scrollViewId = "_ScrollView"
}

/// A protocol that defines a view coordinate space.
public protocol ViewCoordinateSpaceProtocol {
    /// The coordinate space.
    var coordinateSpace: ViewCoordinateSpace { get }
}

/// A global view coordinate space.
public struct GlobalViewCoordinateSpace: ViewCoordinateSpaceProtocol {
    public let coordinateSpace: ViewCoordinateSpace = .global
}

/// A local view coordinate space.
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

/// A named view coordinate space.
public struct NamedViewCoordinateSpace: Equatable, ViewCoordinateSpaceProtocol {
    let name: AnyHashable
    public let coordinateSpace: ViewCoordinateSpace

    /// Initialize a new named view coordinate space.
    ///
    /// - Parameter name: The name of the named view coordinate space.
    init<H: Hashable>(_ name: H) {
        self.name = name
        self.coordinateSpace = .named(AnyHashable(name))
    }

    /// Check if two named view coordinate spaces are equal.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side of the equality check.
    ///   - rhs: The right-hand side of the equality check.
    /// - Returns: A Boolean value indicating whether the two named view coordinate spaces are equal.
    public static func == (lhs: NamedViewCoordinateSpace, rhs: NamedViewCoordinateSpace) -> Bool {
        return lhs.name == rhs.name
    }

    /// Create a new named view coordinate space.
    ///
    /// - Parameter name: The name of the named view coordinate space.
    /// - Returns: A new named view coordinate space.
    public static func named<H: Hashable>(_ name: H) -> NamedViewCoordinateSpace {
        NamedViewCoordinateSpace(name)
    }
}

// MARK: - Geometry Reader

/// A geometry proxy.
@MainActor
public struct GeometryProxy {

    /// The named coordinate space container.
    let namedCoordinateSpaceContainer: NamedViewCoordinateSpaceContainer

    /// The local frame of the geometry proxy.
    let localFrame: Rect

    /// The size of the geometry proxy.
    ///
    /// - Returns: The size of the geometry proxy.
    public var size: Size {
        return localFrame.size
    }

    /// Get the frame of the geometry proxy in a given coordinate space.
    ///
    /// - Parameter coordinateSpace: The coordinate space.
    /// - Returns: The frame of the geometry proxy in the given coordinate space.
    public func frame(in coordinateSpace: ViewCoordinateSpaceProtocol) -> Rect {
        namedCoordinateSpaceContainer.compact()
        switch coordinateSpace.coordinateSpace {
        case .local:
            return self.localFrame
        case .global:
            return namedCoordinateSpaceContainer.containers[ViewRootNode.rootCoordinateSpace.name]?.value?.frame ?? .zero
        case .scrollView:
            return namedCoordinateSpaceContainer.containers[ViewCoordinateSpace.scrollViewId]?.value?.frame ?? .zero
        case .named(let value):
            return namedCoordinateSpaceContainer.containers[value]?.value?.frame ?? .zero
        }
    }
}

/// A geometry reader.
public struct GeometryReader<Content: View>: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let content: (GeometryProxy) -> Content

    /// Initialize a new geometry reader.
    ///
    /// - Parameter content: The content of the geometry reader.
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    /// Build a view node.
    ///
    /// - Parameter context: The build context.
    /// - Returns: The view node.
    func buildViewNode(in context: BuildContext) -> ViewNode {
        GeometryReaderViewNode(contentProxy: content, content: self)
    }
}

/// A geometry reader view node.
final class GeometryReaderViewNode<Content: View>: ViewContainerNode {

    /// The content proxy.
    let contentProxy: (GeometryProxy) -> Content

    /// Initialize a new geometry reader view node.
    ///
    /// - Parameter contentProxy: The content proxy.
    /// - Parameter content: The content.
    init<Root: View>(contentProxy: @escaping (GeometryProxy) -> Content, content: Root) {
        self.contentProxy = contentProxy
        super.init(content: content, body: { _ in fatalError() })
    }

    /// Perform the layout of the geometry reader view node.
    ///
    /// - Returns: The layout of the geometry reader view node.
    override func performLayout() {
        self.invalidateContent()

        for node in self.nodes {
            node.performLayout()
        }
        
        super.performLayout()
    }

    /// Invalidate the content of the geometry reader view node.
    ///
    /// - Returns: The invalidated content of the geometry reader view node.
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

/// A named view coordinate space container.
final class NamedViewCoordinateSpaceContainer: @unchecked Sendable {
    /// The containers of the named view coordinate space.
    var containers: [AnyHashable: WeakBox<ViewNode>] = [:]

    func compact() {
        containers = containers.filter { !$0.value.isEmpty }
    }
}

/// A protocol that defines a coordinate space.
public protocol CoordinateSpace {
    /// The coordinate space.
    var coordinateSpace: ViewCoordinateSpace { get }
}

extension EnvironmentValues {
    /// The coordinate spaces.
    @Entry var coordinateSpaces: NamedViewCoordinateSpaceContainer = NamedViewCoordinateSpaceContainer()
}

public extension View {
    /// The coordinate space of the view.
    ///
    /// - Parameter named: The named view coordinate space.
    /// - Returns: The coordinate space of the view.
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
        context.environment.coordinateSpaces.compact()

        if node is ScrollViewNode {
            context.environment.coordinateSpaces.containers[ViewCoordinateSpace.scrollViewId] = WeakBox(node)
        }

        context.environment.coordinateSpaces.containers[named.name] = WeakBox(node)
        return ViewModifierNode(contentNode: node, content: content)
    }
}
