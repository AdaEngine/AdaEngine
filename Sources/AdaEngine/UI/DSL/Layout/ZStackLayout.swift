//
//  ZStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct ZStackLayout: Layout {
    public typealias Cache = StackLayoutCache

    let anchor: AnchorPoint

    public init(anchor: AnchorPoint = .center) {
        self.anchor = anchor
    }

    public func makeCache(subviews: Subviews) -> Cache {
        var cache = StackLayoutCache()
        self.updateCache(&cache, subviews: subviews)
        return cache
    }

    public func updateCache(_ cache: inout StackLayoutCache, subviews: Subviews) {
        cache = StackLayoutCache()

        for (index, subview) in subviews.enumerated() {
            let minSize = subview.sizeThatFits(.unspecified)

            cache.minSizes.append(minSize)
            cache.minSize += minSize
        }
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size {
        let size = proposal.replacingUnspecifiedDimensions()

        let idealSize = subviews.reduce(Size.zero) { partialResult, subview in
            var newSize = partialResult
            let idealSize = subview.sizeThatFits(ProposedViewSize(width: size.width))
            newSize.width = max(partialResult.width, size.width)
            newSize.height = max(partialResult.height, size.height)
            return newSize
        }

        return Size(
            width: idealSize.width,
            height: idealSize.height
        )
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let size = proposal.replacingUnspecifiedDimensions()

        let origin = Point(
            x: bounds.minX + bounds.width * anchor.x,
            y: bounds.minY + bounds.height * anchor.y
        )

        for (index, subview) in subviews.enumerated() {
            var idealSize = subview.sizeThatFits(proposal)
            let minSize = cache.minSizes[index]

            let width = min(bounds.width, max(idealSize.width, minSize.width))
            let height = min(bounds.height, max(idealSize.height, minSize.height))

            let proposal = ProposedViewSize(width: width, height: height)
            subview.place(at: origin, anchor: anchor, proposal: proposal)
        }
    }
}
