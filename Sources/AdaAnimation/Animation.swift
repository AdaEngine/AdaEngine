//
//  Animation.swift
//  AdaAnimation
//

import AdaUtils

/// A context for an animation (tween curves). UI layers may ignore this; keyframe sampling does not use it.
public struct AnimationContext<V: VectorArithmetic>: Sendable {
    public init() {}
}

/// A protocol that defines the behavior of a custom animation.
public protocol CustomAnimation: Hashable {

    /// Calculates the value of the animation at the specified time.
    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?

    /// The default implementation of this method returns nil.
    func velocity<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?

    /// Determines whether an instance of the animation can merge with other instance of the same type.
    func shouldMerge<V>(
        previous: Animation,
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> Bool where V: VectorArithmetic
}

public extension CustomAnimation {
    func velocity<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V: VectorArithmetic {
        return nil
    }

    func shouldMerge<V>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool where V: VectorArithmetic {
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

        return value.scaled(by: Double(time / duration))
    }

    func velocity<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V: VectorArithmetic {
        value.scaled(by: Double(1.0 / duration))
    }
}

/// A type that represents an animation.
public struct Animation: Equatable, @unchecked Sendable {

    /// The base animation.
    public let base: any CustomAnimation

    /// Initialize a new animation.
    ///
    /// - Parameter base: The base animation.
    public init<T: CustomAnimation>(_ base: T) {
        self.base = base
    }

    /// Check if two animations are equal.
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
    static func linear(duration: TimeInterval) -> Animation {
        Animation(LinearAnimation(duration: duration))
    }

    /// Create a delay animation.
    func delay(_ duration: TimeInterval) -> Animation {
        let delay = Animation(DelayAnimation(duration: duration))
        return Animation(CombineAnimation(left: delay, right: self))
    }
}

/// A delay animation.
struct DelayAnimation: CustomAnimation {

    let duration: TimeInterval

    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else {
            return nil
        }

        return value.scaled(by: Double(time / duration))
    }
}

/// A combine animation.
struct CombineAnimation: CustomAnimation {

    let left: Animation
    let right: Animation

    func animate<V>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V: VectorArithmetic {
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
