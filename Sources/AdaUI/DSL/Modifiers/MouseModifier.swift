//
//  MouseModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

import AdaInput
import Math

public extension View {
    func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        self.modifier(HoverViewModifier(action: action, content: self))
    }
}

// MARK: - HoverViewModifier

struct HoverViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let action: (Bool) -> Void
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        HoverViewModifierNode(
            action: action,
            contentNode: context.makeNode(from: content),
            content: content
        )
    }
}

// MARK: - HoverViewModifierNode

final class HoverViewModifierNode: ViewModifierNode {

    override var allowsNestedFrameAnimation: Bool {
        true
    }

    private let action: (Bool) -> Void
    private var isHovered: Bool = false

    init<Content: View>(action: @escaping (Bool) -> Void, contentNode: ViewNode, content: Content) {
        self.action = action
        super.init(contentNode: contentNode, content: content)
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else { return nil }
        return self
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if event.button == .none && event.phase == .changed {
            if !isHovered {
                isHovered = true
                action(true)
            }
        }
        contentNode.onMouseEvent(event)
    }

    override func onMouseLeave() {
        if isHovered {
            isHovered = false
            action(false)
        }
        super.onMouseLeave()
    }
}

// MARK: - CursorShapeModifier (preserved, not yet active)

struct CursorShapeModifier<Content: View>: View, ViewNodeBuilder {
    typealias Body = Never

    let shape: Input.CursorShape
    let content: Content

    func buildViewNode(in context: BuildContext) -> ViewNode {
        CursorShapeModifierNode(
            shape: self.shape,
            contentNode: context.makeNode(from: content),
            content: content
        )
    }
}

class CursorShapeModifierNode: ViewModifierNode {
    let shape: Input.CursorShape

    init<Content>(shape: Input.CursorShape, contentNode: ViewNode, content: Content) where Content: View {
        self.shape = shape
        super.init(contentNode: contentNode, content: content)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if event.button == .none && event.phase == .changed {
            // Input.pushCursorShape(shape)
        }
        // Input.popCursorShape()
    }
}
