//
//  MouseModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

public extension View {
    func cursorShape(_ shape: Input.CursorShape) -> some View {
        CursorShapeModifier(shape: shape, content: self)
    }

    func onHover(perform action: (Bool) -> Void) -> some View {
        EmptyView()
    }
}

struct CursorShapeModifier<Content: View>: View, ViewNodeBuilder {
    typealias Body = Never

    let shape: Input.CursorShape
    let content: Content

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        CursorShapeModifierNode(
            shape: self.shape,
            contentNode: inputs.makeNode(from: content),
            content: content
        )
    }
}

class CursorShapeModifierNode: ViewModifierNode {
    let shape: Input.CursorShape

    init<Content>(shape: Input.CursorShape, contentNode: ViewNode, content: Content) where Content : View {
        self.shape = shape
        super.init(contentNode: contentNode, content: content)
    }

    override func onMouseEvent(_ event: MouseEvent) {
        // Just moved
        if event.button == .none && event.phase == .changed {
            Input.pushCursorShape(shape)
        }

        Input.popCursorShape()
    }
}
