//
//  Animation+View.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 08.08.2024.
//

import AdaUtils
import Math

public extension View {
    /// Applies the given animation to this view when the specified value changes.
    /// - Parameter animation: The animation to apply. If animation is nil, the view doesn’t animate.
    /// - Parameter value: A value to monitor for changes.
  @MainActor func animation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(_AnimatedViewModifier(content: self, animation: animation, value: value))
    }

    /// Disable any animation for view and their child.
    func disableAnimation() -> some View {
        self.environment(\.animationController, nil)
    }
}

struct _AnimatedViewModifier<Content: View, Value: Equatable>: ViewModifier, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let animation: Animation
    let value: Value

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = AnimatedViewNode(
            contentNode: context.makeNode(from: content),
            content: content,
            value: self.value,
            animation: animation,
            animationController: UIAnimationController(animation: animation)
        )

        node.updateEnvironment(context.environment)
        node.invalidateContent()

        return node
    }
}

class AnimatedViewNode<Value: Equatable>: ViewModifierNode {

    var currentValue: Value
    let animation: Animation
    private var animationController: UIAnimationController

    init<Content: View>(
        contentNode: ViewNode,
        content: Content,
        value: Value,
        animation: Animation,
        animationController: UIAnimationController
    ) {
        self.currentValue = value
        self.animation = animation
        self.animationController = animationController
        super.init(contentNode: contentNode, content: content)
    }

    override func updateEnvironment(_ environment: EnvironmentValues) {
        var environment = environment
        environment.animationController = self.animationController
        super.updateEnvironment(environment)
    }

    override func update(from newNode: ViewNode) {
        var env = newNode.environment
        env.animationController = self.animationController
        newNode.updateEnvironment(env)
        
        super.update(from: newNode)

        guard let node = newNode as? Self else {
            return
        }

        // Move transaction from new to old
        self.animationController = node.animationController

        // Update current stored value and notify about that
        if node.currentValue != self.currentValue {
            self.currentValue = node.currentValue
            self.animationController.playAnimation()
        }
    }

    override func update(_ deltaTime: TimeInterval) async {
        await super.update(deltaTime)

        if animationController.isPlaying {
            animationController.update(deltaTime)
        }
    }
}
