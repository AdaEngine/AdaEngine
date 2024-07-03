//
//  GestureHelpers.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

public extension Gesture {

    func updating<State>(
        _ state: GestureState<State>,
        body: @escaping (Self.Value, inout State) -> Void
    ) -> GestureStateGesture<Self, State> {
        GestureStateGesture(action: body, gesture: self)
    }

    func onChanged(_ action: @escaping (Value) -> Void) -> _OnChangedGesture<Self> {
        _OnChangedGesture(action: action, gesture: self)
    }

    func onEnded(_ action: @escaping (Value) -> Void) -> _OnEndedGesture<Self> {
        _OnEndedGesture(action: action, gesture: self)
    }

    func map<T>(_ block: @escaping (Value) -> T) -> _MapGesture<Self, T> {
        _MapGesture(gesture: self, map: block)
    }
}

public struct _OnChangedGesture<G: Gesture>: Gesture {
    public typealias Value = G.Value
    public typealias Body = Never

    let action: (G.Value) -> Void
    let gesture: G
}

public struct _OnEndedGesture<G: Gesture>: Gesture {

    public typealias Value = G.Value
    public typealias Body = Never

    let action: (G.Value) -> Void
    let gesture: G
}

public struct _MapGesture<G: Gesture, T> {

    public typealias Value = T
    public typealias Body = Never

    let map: (G.Value) -> T
    let gesture: G

    init(gesture: G, map: @escaping (G.Value) -> T) {
        self.gesture = gesture
        self.map = map
    }
}
