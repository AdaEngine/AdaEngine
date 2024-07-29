//
//  OffsetModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 28.07.2024.
//

import Math

public extension View {
    /// Offset this view by the specified horizontal and vertical distances.
    /// - Parameter x: The horizontal distance to offset this view.
    /// - Parameter y: The vertical distance to offset this view.
    /// - Returns: A view that offsets this view by x and y.
    func offset(x: Float = 0, y: Float = 0) -> some View {
        modifier(OffsetViewModifier(x: x, y: y, content: self))
    }

    /// Offset this view by the specified horizontal and vertical distances.
    /// - Parameter point: The distance to offset this view by vertical and horizontal.
    /// - Returns: A view that offsets this view by x and y.
    func offset(_ point: Point) -> some View {
        modifier(OffsetViewModifier(x: point.x, y: point.y, content: self))
    }
}

struct OffsetViewModifier<Content: View>: ViewModifier, ViewNodeBuilder {
    typealias Body = Never

    let x: Float
    let y: Float
    let content: Content

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        let node = OffsetViewNodeModifier(
            contentNode: inputs.makeNode(from: content),
            content: content
        )
        node.offsetByX = x
        node.offsetByY = y

        return node
    }
}

final class OffsetViewNodeModifier: ViewModifierNode {

    var offsetByX: Float = 0
    var offsetByY: Float = 0

    override func place(in origin: Point, anchor: AnchorPoint, proposal: ProposedViewSize) {
        var origin = origin
        origin.x += offsetByX
        origin.y += offsetByY
        
        super.place(in: origin, anchor: anchor, proposal: proposal)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)
        
        guard let node = newNode as? OffsetViewNodeModifier else {
            return
        }

        self.offsetByX = node.offsetByX
        self.offsetByY = node.offsetByY
    }
}
