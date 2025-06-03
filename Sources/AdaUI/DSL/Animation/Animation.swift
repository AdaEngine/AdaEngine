//
//  Animation.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.07.2024.
//

import AdaUtils

/// A context for an animation.
public struct AnimationContext<V: VectorArithmetic> {
    public internal(set) var environment: EnvironmentValues
}

/// A protocol that defines the behavior of a custom animation.
public protocol CustomAnimation: Hashable {

    /// Calculates the value of the animation at the specified time.
    ///
    /// - Parameters:
    ///   - value: The value to animate.
    ///   - time: The elapsed time since the start of the animation.
    ///   - context: The context of the animation.
    /// - Parameter time: The elapsed time since the start of the animation.
    /// - Returns: The current value of the animation, or `nil` if the animation has finished.
    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?

    /// The default implementation of this method returns nil.
    func velocity<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?

    /// Determines whether an instance of the animation can merge with other instance of the same type.
    func shouldMerge<V>(
        previous: Animation,
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> Bool where V : VectorArithmetic
}

public extension CustomAnimation {
    func velocity<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {
        return nil
    }

    func shouldMerge<V>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool where V : VectorArithmetic {
        return false
    }
}

/// A linear animation.
struct LinearAnimation: CustomAnimation {

    let duration: TimeInterval

    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else {
            return nil
        }
        
        return value.scaled(by: Double(time/duration))
    }

    func velocity<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {
        value.scaled(by: Double(1.0 / duration))
    }
}

/// A type that represents an animation.
public struct Animation: Equatable, @unchecked Sendable {

    /// The base animation.
    let base: any CustomAnimation

    /// Initialize a new animation.
    ///
    /// - Parameter base: The base animation.
    init<T: CustomAnimation>(_ base: T) {
        self.base = base
    }

    /// Check if two animations are equal.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side of the comparison.
    ///   - rhs: The right-hand side of the comparison.
    /// - Returns: A Boolean value indicating whether the two animations are equal.
    public static func == (lhs: Animation, rhs: Animation) -> Bool {
        return lhs.base.hashValue == rhs.base.hashValue
    }
}

/// A default animation.
public extension Animation {
    /// The default animation.
    static let `default`: Animation = .linear

    /// A linear animation.
    static let linear: Animation = .linear(duration: 1)

    /// Create a linear animation.
    ///
    /// - Parameter duration: The duration of the animation.
    /// - Returns: A linear animation.
    static func linear(duration: TimeInterval) -> Animation {
        Animation(LinearAnimation(duration: duration))
    }

    /// Create a delay animation.
    ///
    /// - Parameter duration: The duration of the delay.
    /// - Returns: A delay animation.
    func delay(_ duration: TimeInterval) -> Animation {
        let delay = Animation(DelayAnimation(duration: duration))
        return Animation(CombineAnimation(left: delay, right: self))
    }
}

/// A delay animation.
struct DelayAnimation: CustomAnimation {

    /// The duration of the delay.
    let duration: TimeInterval

    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else {
            return nil
        }

        return value.scaled(by: Double(time/duration))
    }
}

/// A combine animation.
struct CombineAnimation: CustomAnimation {

    /// The left animation.
    let left: Animation

    /// The right animation.
    let right: Animation

    func animate<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {
        if let value = left.base.animate(value, time: time, context: &context) {
            return value
        }

        return right.base.animate(value, time: time, context: &context)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(left.base)
        hasher.combine(right.base)
    }
}
