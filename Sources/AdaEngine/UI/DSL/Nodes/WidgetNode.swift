//
//  WidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

/// Base node for all system widgets in AdaEngine.
/// Node represents a view that can render, layout and interact with user.
@MainActor class WidgetNode: Identifiable {

    nonisolated var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    weak var parent: WidgetNode?

    var content: any Widget
    var storages: [UpdatablePropertyStorage] = []
    private(set) var environment = WidgetEnvironmentValues()
    private(set) var frame: Rect = .zero
    private(set) var layoutProperties = LayoutProperties()

    init<Content: Widget>(content: Content) {
        self.content = content

        defer {
            self.storages = WidgetNodeBuilderUtils.findPropertyStorages(in: content, node: self)
        }
    }

    // MARK: Layout

    func updateEnvironment(_ environment: WidgetEnvironmentValues) {
        self.environment = environment
    }

    func invalidateContent() { }

    func updateLayoutProperties(_ props: LayoutProperties) {
        self.layoutProperties = props
    }

    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }

    func place(in origin: Point, anchor: AnchorPoint, proposal: ProposedViewSize) {
        let size = self.sizeThatFits(proposal)
        let offset = Point(
            x: origin.x - size.width * anchor.x,
            y: origin.y - size.height * anchor.y
        )

        self.frame = Rect(origin: offset, size: size)

        self.performLayout()
    }

    func performLayout() { }

    // MARK: - Other

    func update(_ deltaTime: TimeInterval) { }

    func draw(with context: GUIRenderContext) { }
    
    // MARK: - Interaction
    
    func onReceiveEvent(_ event: InputEvent) { }

    func hitTest(_ point: Point, with event: InputEvent) -> WidgetNode? {
        if self.point(inside: point, with: event) {
            return self
        }

        return nil
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.frame.contains(point: point)
    }

    func convert(_ point: Point, to node: WidgetNode?) -> Point {
        guard let node, node !== self else {
            return point
        }

        if node.parent === self {
            return (point - node.frame.origin)
        } else if let parent, parent === node {
            return point + frame.origin
        }
        
        return point
    }

    func convert(_ point: Point, from node: WidgetNode?) -> Point {
        return node?.convert(point, to: self) ?? point
    }

    open func onTouchesEvent(_ touches: Set<TouchEvent>) {

    }

    open func onMouseEvent(_ event: MouseEvent) {

    }

    // MARK: - Debug

    func _printDebugNode() {
        print(self.debugDescription(hierarchy: 0))
    }

    func debugDescription(hierarchy: Int = 0, identation: Int = 2) -> String {
        let identation = String(repeating: " ", count: hierarchy * identation)
        return """
        \(identation)\(type(of: self)):
        \(identation)\(identation)- frame: \(frame)
        \(identation)\(identation)- content: \(type(of: self.content))
        """
    }
}

public struct AnchorPoint : Hashable, Sendable {
    public var x: Float = 0
    public var y: Float = 0

    public init() { }

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static let zero = AnchorPoint(x: 0.0, y: 0.0)
    public static let center = AnchorPoint(x: 0.5, y: 0.5)
    public static let leading = AnchorPoint(x: 0.0, y: 0.5)
    public static let trailing = AnchorPoint(x: 1.0, y: 0.5)
    public static let top = AnchorPoint(x: 0.5, y: 0.0)
    public static let bottom = AnchorPoint(x: 0.5, y: 1.0)

    public static let topLeading = AnchorPoint(x: 0.0, y: 0.0)
    public static let topTrailing = AnchorPoint(x: 1.0, y: 0.0)
    public static let bottomLeading = AnchorPoint(x: 0.0, y: 1.0)
    public static let bottomTrailing = AnchorPoint(x: 1.0, y: 1.0)
}
