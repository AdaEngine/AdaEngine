//
//  ViewNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Observation
import Math

// TODO: Add texture for drawing, to avoid rendering each time.

/// Build block for all system Views in AdaEngine.
/// Node represents a view that can be render, layout and interact.
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

    /// View can be marked as notifiable about changes when called ``View/printChanges()`` method.
    private(set) var shouldNotifyAboutChanges: Bool

    /// Content relative a view node. We use this copy of content to compare views.
    private(set) var content: any View

    /// Contains current environment values.
    private(set) var environment = EnvironmentValues()

    private(set) var frame: Rect = .zero
    private(set) var layoutProperties = LayoutProperties()
    private(set) var gestures: [_Gesture] = []
    private(set) var preferences = PreferenceValues()

    init<Content: View>(content: Content) {
        self.content = content
        self.shouldNotifyAboutChanges = ViewGraph.shouldNotifyAboutChanges(Content.self)
    }
    
    /// Set a new content for view node.
    /// - Note: This method don't call ``invalidateContent()`` method
    func setContent<Content: View>(_ content: Content) {
        self.content = content
        self.shouldNotifyAboutChanges = ViewGraph.shouldNotifyAboutChanges(Content.self)
    }

    // MARK: Layout

    func updatePreference<K: PreferenceKey>(key: K.Type, value: K.Value) {
        let updatedValue = parent?.preferences[K.self] ?? K.defaultValue
        self.parent?.updatePreference(key: K.self, value: updatedValue)
    }

    /// Updates stored environment.
    /// Called each time, when environment values did change.
    func updateEnvironment(_ environment: EnvironmentValues) {
        self.environment = environment
    }

    /// Update layout properties for view. 
    /// Called each time, when parent container view did change layout direction.
    func updateLayoutProperties(_ props: LayoutProperties) {
        self.layoutProperties = props
    }

    /// Returns size for view node in measuring cycle.
    /// Parent view proposal sizes and views should calculate theirs sizes for given constraints.
    func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return proposal.replacingUnspecifiedDimensions()
    }
    
    /// Place view in specific point and anchor.
    /// After placement, automatically call ``performLayout()`` method.
    func place(in origin: Point, anchor: AnchorPoint, proposal: ProposedViewSize) {
        let size = self.sizeThatFits(proposal)
        let offset = Point(
            x: origin.x - size.width * anchor.x,
            y: origin.y - size.height * anchor.y
        )

        self.frame = Rect(origin: offset, size: size)

        self.performLayout()
    }

    /// Updates view layout. Called when needs update UI layout.
    func performLayout() { }

    func isEquals(_ otherNode: ViewNode) -> Bool {
        // Compare content of POD or Equals
        if _ViewGraphNode(value: self.content) == _ViewGraphNode(value: otherNode.content) {
            return true
        }

        return false
    }

    /// Merge two views into one. This method called after ``invalidationContent()`` method
    /// and if view exists in tree, we should update exsiting view using ``merge(_:)`` method.
    func merge(_ otherNode: ViewNode) {
        self.environment = otherNode.environment

        if let animatable = self.content as? any Animatable {
            var data = animatable.animatableData
            
        }
    }

    /// This method invalidate all stored views and create a new one.
    func invalidateContent() { }

    /// Notify view, that view will move to parent view.
    func willMove(to parent: ViewNode?) { }

    /// Notify view, that view did move to parent view.
    func didMove(to parent: ViewNode?) { }

    // MARK: - Other

    func update(_ deltaTime: TimeInterval) async { }

    /// Perform draw view on the screen.
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
