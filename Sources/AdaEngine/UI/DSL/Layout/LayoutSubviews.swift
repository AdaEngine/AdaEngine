//
//  LayoutSubviews.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct LayoutSubview: Equatable {

    let node: WidgetNode

    public static func == (lhs: LayoutSubview, rhs: LayoutSubview) -> Bool {
        return lhs.node.id == rhs.node.id
    }

    @MainActor
    public func place(at point: Point, anchor: AnchorPoint, proposal: ProposedViewSize) {
        node.place(in: point, anchor: anchor, proposal: proposal)
    }

    @MainActor
    public func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        return self.node.sizeThatFits(proposal)
    }

    @MainActor
    func dimensions(in proposal: ProposedViewSize) -> Size {
        return node.frame.size
    }
}

public struct LayoutSubviews: Sequence, Collection {
    public func index(after i: Int) -> Int {
        return self.data.index(after: i)
    }

    public subscript(position: Int) -> LayoutSubview {
        _read {
            yield self.data[position]
        }
    }

    public typealias Element = LayoutSubview
    public typealias Iterator = IndexingIterator<[Element]>

    let data: [Element]

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
