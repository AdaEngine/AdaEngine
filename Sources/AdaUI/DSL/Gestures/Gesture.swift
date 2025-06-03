//
//  Gesture.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import AdaUtils
import AdaInput
import Math

/// A protocol that defines a gesture for views.
public protocol Gesture<Value> {

    /// The value of the gesture.
    associatedtype Value

    /// The body of the gesture.
    associatedtype Body: Gesture

    /// The body of the gesture.
    var body: Body { get }

    /// Make a gesture.
    ///
    /// - Parameters:
    ///   - gesture: The gesture.
    ///   - inputs: The inputs.
    /// - Returns: The gesture.
    @MainActor
    static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture
}

/// A protocol that defines a gesture for views.
extension Gesture {

    /// Make a gesture.
    ///
    /// - Parameters:
    ///   - gesture: The gesture.
    ///   - inputs: The inputs.
    /// - Returns: The gesture.
    @MainActor
    public static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture {
        fatalError()
    }
}

/// A view modifier that applies a gesture to a view.
struct GestureViewModifier<G: Gesture, Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let gesture: G
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        GestureAreaViewNode(contentNode: context.makeNode(from: content), content: content)
    }
}

/// A gesture.
@MainActor
public class _Gesture {

    weak var node: ViewNode?

    /// Called when a event is received.
    ///
    /// - Parameter event: The event.
    func onReceiveEvent(_ event: any InputEvent) {

    }

    /// Called when a mouse event is received.
    ///
    /// - Parameter event: The event.
    func onMouseEvent(_ event: MouseEvent) {
        
    }

}

extension Never: Gesture {
    public typealias Value = Void
}

public extension Gesture where Body == Never {
    var body: Never {
        fatalError()
    }
}

/// A tap gesture.
public struct TapGesture: Gesture {
    public typealias Value = Void
    public typealias Body = Never

    /// The required number of tap events.
    public var count: Int

    /// Creates a tap gesture with the number of required taps.
    public init(count: Int) {
        self.count = count
    }
}

/// A long press gesture.
public struct LongPressGesture: Gesture {

    public typealias Value = Void
    public typealias Body = Never

    public var minimumDuration: TimeInterval = 1

    public init(minimumDuration: TimeInterval = 1) {
        self.minimumDuration = minimumDuration
    }
}

/// A gesture state gesture.
public struct GestureStateGesture<G: Gesture, State>: Gesture {
    public typealias Value = G.Value
    public typealias Body = Never

    let action: (G.Value, inout State) -> Void
    let gesture: G
}

/// A gesture recognizer.
class GestureRecognizer {
    
}

/// A gesture area view node.
class GestureAreaViewNode: ViewModifierNode {

    var gestures: [GestureRecognizer] = []

    /// Hit test the gesture area view node.
    ///
    /// - Parameters:
    ///   - point: The point to hit test.
    ///   - event: The event to hit test with.
    /// - Returns: The view node that was hit.
    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        return contentNode
    }

    /// Called when a mouse event is received.
    ///
    /// - Parameter event: The event.
    override func onMouseEvent(_ event: MouseEvent) {

    }

    /// Called when a touches event is received.
    ///
    /// - Parameter touches: The touches event.
    override func onTouchesEvent(_ touches: Set<TouchEvent>) {

    }

    /// Called when a event is received.
    ///
    /// - Parameter event: The event.
    override func onReceiveEvent(_ event: any InputEvent) {

    }
}
