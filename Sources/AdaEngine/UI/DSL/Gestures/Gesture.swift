//
//  Gesture.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.07.2024.
//

public protocol Gesture<Value> {

    associatedtype Value

    associatedtype Body: Gesture

    var body: Body { get }

    static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture
}

extension Gesture {
    @MainActor public static func _makeGesture(gesture: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _Gesture {
        fatalError()
    }
}

struct GestureViewModifier<G: Gesture>: ViewModifier, _ViewInputsViewModifier {
    typealias Body = Never

    let gesture: G

    static func _makeModifier(_ modifier: _ViewGraphNode<GestureViewModifier<G>>, inputs: inout _ViewInputs) {
        let gesture = modifier[\.gesture]
        let uiGesture = G._makeGesture(gesture: gesture, inputs: inputs)
        inputs.gestures.append(uiGesture)
    }
}

@MainActor
public class _Gesture {

//    var onChanged: ((Value) -> Void)?
//    var onEnded: ((Value) -> Void)?

    weak var node: ViewNode?

    func onReceiveEvent(_ event: InputEvent) {

    }

    func onMouseEvent(_ event: MouseEvent) {
        
    }

    func hitTest(_ point: Point, with event: InputEvent) -> ViewNode? {
        if self.point(inside: point, with: event) {
            return self.node
        }

        return nil
    }

    /// - Returns: true if point is inside the receiver’s bounds; otherwise, false.
    func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.node?.frame.contains(point: point) ?? false
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
