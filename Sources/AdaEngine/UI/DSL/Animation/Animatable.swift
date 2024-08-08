//
//  Animatable.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 08.08.2024.
//

import Math

public protocol Animatable {
    /// The type defining the data to animate.
    associatedtype AnimatableData: VectorArithmetic

    /// The data to animate.
    var animatableData: AnimatableData { get set }
}

public extension Animatable where Self : VectorArithmetic {

    /// The data to animate.
    var animatableData: Self {
        get { self }
        set { self = newValue }
    }
}

public extension Animatable where Self.AnimatableData == EmptyAnimatableData {

    /// The data to animate.
    var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        // swiftlint:disable:next unused_setter_value
        set { }
    }
}

public struct EmptyAnimatableData: VectorArithmetic {
    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData(value: lhs.value - rhs.value)
    }

    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData(value: lhs.value + rhs.value)
    }

    public static var zero: EmptyAnimatableData = EmptyAnimatableData(value: 0)

    var value: Double

    init(value: Double) {
        self.value = value
    }

    public init() {
        self.value = 0
    }

    public mutating func scale(by rhs: Double) {
        value = value * rhs
    }

    public var magnitudeSquared: Double { return 0 }
}
