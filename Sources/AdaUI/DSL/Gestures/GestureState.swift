//
//  GestureState.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

@propertyWrapper
public struct GestureState<Value> {
    let initialState: Value
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.initialState = wrappedValue
        self.wrappedValue = wrappedValue
    }
}
