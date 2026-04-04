//
//  TransformEffectViewNode.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 06.08.2024.
//

import Math

public extension View {

    /// Scales this view’s rendered output by the given vertical and horizontal size amounts.
    func scaleEffect(_ scale: Vector2, anchor: AnchorPoint = .center) -> some View {
        modifier(
            TransformViewModifier(
                value: scale,
                mapTransform: { transform, value in
                    transform = Transform3D(scale: Vector3(value, 1))
                },
                anchor: anchor,
                content: self
            )
        )
    }

    /// Rotates a view’s rendered output in two dimensions around the specified point.
    func rotationEffect(_ angle: Angle) -> some View {
        modifier(
            TransformViewModifier(
                value: angle.radians,
                mapTransform: { transform, value in
                    transform = Transform3D(quat: Quat(axis: Vector3(0, 0, 1), angle: Float(value)))
                },
                anchor: .zero,
                content: self
            )
        )
    }
}

struct TransformViewModifier<Content: View, Value: VectorArithmetic>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    var value: Value
    let mapTransform: (inout Transform3D, Value) -> Void
    let anchor: AnchorPoint
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        let node = TransformEffectViewNode(
            contentNode: context.makeNode(from: content),
            content: content,
            value: value,
            mapTransform: mapTransform
        )

        node.anchor = self.anchor
        return node
    }
}

final class TransformEffectViewNode<Value: VectorArithmetic>: ViewModifierNode {
    var value: Value
    let mapTransform: (inout Transform3D, Value) -> Void
    var anchor: AnchorPoint = .center

    init<Content>(
        contentNode: ViewNode,
        content: Content,
        value: Value,
        mapTransform: @escaping (inout Transform3D, Value) -> Void
    ) where Content : View {
        self.value = value
        self.mapTransform = mapTransform
        super.init(contentNode: contentNode, content: content)
        self.updateTransform(value)
    }

    private var localTransform = Transform3D.identity

    override func update(from newNode: ViewNode) {
        let animationController = self.environment.animationController
        super.update(from: newNode)

        guard let newNode = newNode as? Self else {
            return
        }

        if let animationController = animationController {
            animationController.addTweenAnimation(
                from: TweenValue(animatableData: self.value),
                to: TweenValue(animatableData: newNode.value),
                label: self.id,
                environment: self.environment,
                updateBlock: { [weak self] value in
                    self?.updateTransform(value.animatableData)
                }
            )

            self.value = newNode.value
        } else {
            self.value = newNode.value
            updateTransform(self.value)
        }
    }

    private func updateTransform(_ value: Value) {
        var transform = localTransform
        mapTransform(&transform, value)
        self.localTransform = transform
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.concatenate(self.localTransform)
        contentNode.draw(with: context)
    }
}

// MARK: - AnimatableOffset

struct AnimatableOffsetModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let x: Float
    let y: Float
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        AnimatableOffsetNode(
            contentNode: context.makeNode(from: content),
            content: content,
            x: x,
            y: y
        )
    }
}

final class AnimatableOffsetNode: ViewModifierNode {

    private var targetX: Float
    private var targetY: Float
    private var visualX: Float
    private var visualY: Float

    init<Content: View>(contentNode: ViewNode, content: Content, x: Float, y: Float) {
        self.targetX = x
        self.targetY = y
        self.visualX = x
        self.visualY = y
        super.init(contentNode: contentNode, content: content)
    }

    override func update(from newNode: ViewNode) {
        let animationController = self.environment.animationController
        super.update(from: newNode)
        guard let node = newNode as? AnimatableOffsetNode else { return }

        if let controller = animationController {
            controller.addTweenAnimation(
                from: TweenValue(animatableData: Vector2(visualX, visualY)),
                to: TweenValue(animatableData: Vector2(node.targetX, node.targetY)),
                label: self.id,
                environment: self.environment,
                updateBlock: { [weak self] val in
                    guard let self else { return }
                    self.visualX = val.animatableData.x
                    self.visualY = val.animatableData.y
                    self.invalidateNearestLayer()
                    self.owner?.containerView?.setNeedsDisplay(in: self.absoluteFrame())
                }
            )
        } else {
            self.visualX = node.targetX
            self.visualY = node.targetY
        }

        self.targetX = node.targetX
        self.targetY = node.targetY
    }

    override func draw(with context: UIGraphicsContext) {
        var ctx = context
        ctx.environment = environment
        ctx.translateBy(x: self.frame.origin.x + visualX, y: -(self.frame.origin.y + visualY))
        contentNode.draw(with: ctx)
    }
}

public extension View {

    /// Offsets this view visually using a position that participates in the animation system.
    ///
    /// Unlike `.offset(x:y:)`, this modifier can be animated with `.animation(_:value:)`.
    func animatableOffset(x: Float = 0, y: Float = 0) -> some View {
        modifier(AnimatableOffsetModifier(x: x, y: y, content: self))
    }
}
