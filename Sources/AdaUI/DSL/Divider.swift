//
//  Divider.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 04.08.2024.
//

import AdaUtils
import Math

/// A view that draws a divider.
public struct Divider: View, ViewNodeBuilder {

    /// Initialize a new divider.
    public init() {}

    /// The body of the divider.
    public var body: Never {
        fatalError()
    }

    /// Build a view node.
    ///
    /// - Parameter context: The build context.
    /// - Returns: The view node.
    func buildViewNode(in context: BuildContext) -> ViewNode {
        return DividerNode(content: self)
    }
}

/// A node that draws a divider.
final class DividerNode: ViewNode {

    /// Draw the divider.
    ///
    /// - Parameter context: The graphics context.
    override func draw(with context: UIGraphicsContext) {
        context.drawRect(
            Rect(
                origin: .zero,
                size: Size(width: frame.width, height: 1)
            ),
            color: .gray
        )
    }

    /// Calculate the size that fits the proposal.
    ///
    /// - Parameter proposal: The proposed view size.
    /// - Returns: The size that fits the proposal.
    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero {
            return proposal.replacingUnspecifiedDimensions()
        }

        var size = proposal.replacingUnspecifiedDimensions()
        if layoutProperties.stackOrientation == .horizontal {
            size.height = 0
        } else if layoutProperties.stackOrientation == .vertical {
            size.width = 0
        }

        return size

    }
}
