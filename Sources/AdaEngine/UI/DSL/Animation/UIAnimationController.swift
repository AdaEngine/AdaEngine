//
//  UIAnimationController.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 08.08.2024.
//

import Math

enum _AnimationState {
    case idle
    case playing
    case done
}

protocol _AnimationTransaction {
    var state: _AnimationState { get }
    var label: AnyHashable { get }
    mutating func updateAnimation(_ deltaTime: TimeInterval)
}

final class UIAnimationController {

    private(set) var isPlaying: Bool = false

    struct TweenAnimation<T: Animatable>: _AnimationTransaction {
        var state: _AnimationState = .idle
        let animation: Animation
        var label: AnyHashable
        var fromValue: T
        var toValue: T
        var currentValue: T!
        let updateBlock: (T) -> Void
        var currentDuration: TimeInterval = 0
        var animationContext: AnimationContext<T.AnimatableData>

        mutating func updateAnimation(_ deltaTime: TimeInterval) {
            if state == .idle {
                state = .playing
                currentValue = fromValue
            }

            if state == .done {
                return
            }

            self.currentDuration += deltaTime
            if let value = self.animation.base.animate(fromValue.animatableData - toValue.animatableData, time: self.currentDuration, context: &animationContext) {
                currentValue.animatableData = fromValue.animatableData - value
                self.updateBlock(currentValue)
                return
            } else {
                self.updateBlock(toValue)
            }

            self.state = .done
        }
    }

    let animation: Animation
    private var transactions: [_AnimationTransaction] = []

    init(animation: Animation) {
        self.animation = animation
    }

    func addTweenAnimation<T: Animatable>(
        from beginValue: T,
        to endValue: T,
        label: AnyHashable,
        environment: EnvironmentValues,
        updateBlock: @escaping (T) -> Void
    ) {
        if let index = self.transactions.firstIndex(where: { $0.label == label }) {
            // If we add same animation -> remove previous and add a new one.
            self.transactions.remove(at: index)
        }
        self.transactions.append(
            TweenAnimation(
                animation: self.animation,
                label: label,
                fromValue: beginValue,
                toValue: endValue,
                updateBlock: updateBlock,
                animationContext: AnimationContext(environment: environment)
            )
        )
    }

    func playAnimation() {
        self.isPlaying = true
    }

    func stopAnimation() {
        self.isPlaying = false
    }

    func update(_ deltaTime: TimeInterval) {
        guard self.isPlaying, !transactions.isEmpty else {
            return
        }

        for (index, transaction) in transactions.enumerated() {
            var transaction = transaction
            transaction.updateAnimation(deltaTime)
            transactions[index] = transaction
        }

        transactions.removeAll(where: { $0.state == .done })

        if transactions.isEmpty {
            self.isPlaying = false
        }
    }
}

extension EnvironmentValues {
    @Entry var animationController: UIAnimationController?
}

struct TweenValue<Value: VectorArithmetic>: Animatable {
    var animatableData: Value
}
