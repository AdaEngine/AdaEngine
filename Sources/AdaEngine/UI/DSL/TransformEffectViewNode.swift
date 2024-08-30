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
        super.update(from: newNode)

        guard let newNode = newNode as? Self else {
            return
        }

        if let animationController = self.environment.animationController {
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
