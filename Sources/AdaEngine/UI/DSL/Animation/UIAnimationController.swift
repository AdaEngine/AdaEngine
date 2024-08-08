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
        let updateBlock: (T.AnimatableData) -> Void
        var currentDuration: TimeInterval = 0
        var animationContext: AnimationContext<Float>

        mutating func updateAnimation(_ deltaTime: TimeInterval) {
            if state == .idle {
                state = .playing
            }

            if state == .done {
                return
            }

            self.currentDuration += deltaTime
            if let value = self.animation.base.animate(self.fromValue.animatableData, time: self.currentDuration, context: &animationContext) {
                self.updateBlock(newValue)
                return
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
        updateBlock: @escaping (T.AnimatableData) -> Void
    ) {
        if self.transactions.contains(where: { $0.label == label }) {
            return
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

        for index in transactions.indices {
            var transaction = transactions[index]
            transaction.updateAnimation(deltaTime)
            transactions[index] = transaction

            if transaction.state == .done {
                print("animation finished")
                transactions.remove(at: index)
            }
        }

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
