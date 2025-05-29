//
//  Animation.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.07.2024.
//

import AdaUtils

public struct AnimationContext<V: VectorArithmetic> {
    public internal(set) var environment: EnvironmentValues
}

public protocol CustomAnimation: Hashable {
    /// Calculates the value of the animation at the specified time.
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

public struct Animation: Equatable, @unchecked Sendable {

    let base: any CustomAnimation

    init<T: CustomAnimation>(_ base: T) {
        self.base = base
    }

    public static func == (lhs: Animation, rhs: Animation) -> Bool {
        return lhs.base.hashValue == rhs.base.hashValue
    }
}

public extension Animation {
    static let `default`: Animation = .linear

    static let linear: Animation = .linear(duration: 1)

    static func linear(duration: TimeInterval) -> Animation {
        Animation(LinearAnimation(duration: duration))
    }

    func delay(_ duration: TimeInterval) -> Animation {
        let delay = Animation(DelayAnimation(duration: duration))
        return Animation(CombineAnimation(left: delay, right: self))
    }
}

struct DelayAnimation: CustomAnimation {
    let duration: TimeInterval

    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else {
            return nil
        }

        return value.scaled(by: Double(time/duration))
    }
}

struct CombineAnimation: CustomAnimation {
    let left: Animation
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
