//
//  ViewNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Observation
import Math

/// Base node for all system Views in AdaEngine.
/// Node represents a view that can render, layout and interact with user.
@MainActor
class ViewNode: Identifiable {

    nonisolated var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    weak var parent: ViewNode? {
        willSet {
            willMove(to: newValue)
        }
        didSet {
            didMove(to: self.parent)
        }
    }

    private(set) var shouldNotifyAboutChanges: Bool
    private(set) var content: any View
    private(set) var environment = EnvironmentValues()
    private(set) var frame: Rect = .zero
    private(set) var layoutProperties = LayoutProperties()
    private(set) var gestures: [_Gesture] = []
    private(set) var preferences = PreferenceValues()

    init<Content: View>(content: Content) {
        self.content = content
        self.shouldNotifyAboutChanges = ViewGraph.shouldNotifyAboutChanges(Content.self)
    }

    func setContent<Content: View>(_ content: Content) {
        self.content = content
        self.shouldNotifyAboutChanges = ViewGraph.shouldNotifyAboutChanges(Content.self)
    }

    // MARK: Layout

    func updatePreference<K: PreferenceKey>(key: K.Type, value: K.Value) {
        let updatedValue = parent?.preferences[K.self] ?? K.defaultValue
        self.parent?.updatePreference(key: K.self, value: updatedValue)
    }

    func updateEnvironment(_ environment: EnvironmentValues) {
        self.environment = environment
    }

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

    /// Called when need update UI layout.
    func performLayout() { }

    func isEquals(_ otherNode: ViewNode) -> Bool {
        // Compare content of POD or Equals
        if _ViewGraphNode(value: self.content) == _ViewGraphNode(value: otherNode.content) {
            return true
        }

        return false
    }

    func merge(_ otherNode: ViewNode) {
        self.environment = otherNode.environment
    }

    func invalidateContent() { }

    func willMove(to parent: ViewNode?) { }

    func didMove(to parent: ViewNode?) { }

    // MARK: - Other

    func update(_ deltaTime: TimeInterval) async { }

    func draw(with context: UIGraphicsContext) { }
    
    // MARK: - Interaction
    
    func onReceiveEvent(_ event: InputEvent) { }

    func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        if self.point(inside: point, with: event) {
            return self
        }

        return nil
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.frame.contains(point: point)
    }

    func convert(_ point: Point, to node: ViewNode?) -> Point {
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

    func convert(_ point: Point, from node: ViewNode?) -> Point {
        return node?.convert(point, to: self) ?? point
    }

    func onTouchesEvent(_ touches: Set<TouchEvent>) {

    }

    func onMouseEvent(_ event: MouseEvent) {

    }

    func findFirstResponder(for event: InputEvent) -> ViewNode? {
        let responder: ViewNode?

        switch event {
        case let event as MouseEvent:
            let point = event.mousePosition
            responder = self.hitTest(point, with: event)
        case let event as TouchEvent:
            let point = event.location
            responder = self.hitTest(point, with: event)
        default:
            return nil
        }

        return responder
    }

    // MARK: - Debug

    func _printDebugNode() {
//        print(self.debugDescription(hierarchy: 0))
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

extension ViewNode: Equatable {
    static func == (lhs: ViewNode, rhs: ViewNode) -> Bool {
        return lhs.isEquals(rhs)
    }
}
