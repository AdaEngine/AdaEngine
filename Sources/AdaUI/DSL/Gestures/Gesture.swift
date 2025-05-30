//
//  Gesture.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

import AdaUtils
import AdaInput
import Math

public protocol Gesture<Value> {

    associatedtype Value
    associatedtype Body: Gesture

    var body: Body { get }

    @MainActor
    static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture
}

extension Gesture {
    @MainActor
    public static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture {
        fatalError()
    }
}

struct GestureViewModifier<G: Gesture, Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let gesture: G
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        GestureAreaViewNode(contentNode: context.makeNode(from: content), content: content)
    }
}

@MainActor
public class _Gesture {

    weak var node: ViewNode?

    func onReceiveEvent(_ event: any InputEvent) {

    }

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

public struct LongPressGesture: Gesture {

    public typealias Value = Void
    public typealias Body = Never

    public var minimumDuration: TimeInterval = 1

    public init(minimumDuration: TimeInterval = 1) {
        self.minimumDuration = minimumDuration
    }
}

public struct GestureStateGesture<G: Gesture, State>: Gesture {
    public typealias Value = G.Value
    public typealias Body = Never

    let action: (G.Value, inout State) -> Void
    let gesture: G
}

class GestureRecognizer {
    
}

class GestureAreaViewNode: ViewModifierNode {

    var gestures: [GestureRecognizer] = []

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        return contentNode
    }

    override func onMouseEvent(_ event: MouseEvent) {

    }

    override func onTouchesEvent(_ touches: Set<TouchEvent>) {

    }

    override func onReceiveEvent(_ event: any InputEvent) {

    }
}
