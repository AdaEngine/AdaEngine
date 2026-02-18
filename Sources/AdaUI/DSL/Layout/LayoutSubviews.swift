//
//  LayoutSubviews.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

/// A layout subview.
public struct LayoutSubview: Equatable {

    /// The node.
    unowned let node: ViewNode

    /// Check if two layout subviews are equal.
    ///
    /// - Parameter lhs: The left layout subview.
    /// - Parameter rhs: The right layout subview.
    /// - Returns: A Boolean value indicating whether the two layout subviews are equal.
    public static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        return lhs.node.id == rhs.node.id
    }

    /// Place the layout subview at a specific point.
    ///
    /// - Parameter point: The point to place the layout subview at.
    /// - Parameter anchor: The anchor point.
    /// - Parameter proposal: The proposed view size.
    @MainActor
    public func place(at point: Point, anchor: AnchorPoint, proposal: ProposedViewSize) {
        node.place(in: point, anchor: anchor, proposal: proposal)
    }

    /// Calculate the size that fits the proposal.
    ///
    /// - Parameter proposal: The proposed view size.
    /// - Returns: The size that fits the proposal.
    @MainActor
    public func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return self.node.sizeThatFits(proposal)
    }

    /// Calculate the dimensions of the layout subview.
    ///
    /// - Parameter proposal: The proposed view size.
    /// - Returns: The dimensions of the layout subview.
    @MainActor
    func dimensions(in proposal: ProposedViewSize) -> Size {
        return node.frame.size
    }
}

/// A layout subviews.
public struct LayoutSubviews: Sequence, Collection {
    /// Get the next index after the given index.
    ///
    /// - Parameter i: The index.
    /// - Returns: The next index.
    public func index(after i: Int) -> Int {
        return self.data.index(after: i)
    }

    /// Get the layout subview at the given position.
    ///
    /// - Parameter position: The position.
    /// - Returns: The layout subview.
    public subscript(position: Int) -> LayoutSubview {
        _read {
            yield self.data[position]
        }
    }

    /// The element type.
    public typealias Element = LayoutSubview
    /// The iterator type.
    public typealias Iterator = IndexingIterator<[Element]>

    /// The data.
    let data: [Element]

    /// Initialize a new layout subviews.
    ///
    /// - Parameter data: The data.
    init(_ data: [Element]) {
        self.data = data
    }

    public var startIndex: Int {
        data.startIndex
    }

    public var endIndex: Int {
        data.endIndex
    }

    public func makeIterator() -> IndexingIterator<[Element]> {
        return data.makeIterator()
    }
}
