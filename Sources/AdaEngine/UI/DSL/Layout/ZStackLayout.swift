//
//  ZStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct ZStackLayout: Layout {
    public typealias Cache = StackLayoutCache
    public typealias AnimatableData = EmptyAnimatableData

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

        for subview in subviews {
            let minSize = subview.sizeThatFits(.unspecified)

            cache.minSizes.append(minSize)
            cache.minSize += minSize
        }
    }
    
    public func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size {
        let idealSize = subviews.reduce(Size.zero) { partialResult, subview in
            let idealSize = subview.sizeThatFits(proposal)

            if idealSize.width == proposal.width && idealSize.height == proposal.height {
                return partialResult
            }

            var newSize = partialResult
            newSize.width = max(partialResult.width, idealSize.width)
            newSize.height = max(partialResult.height, idealSize.height)
            return newSize
        }

        return Size(
            width: idealSize.width,
            height: idealSize.height
        )
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let origin = Point(
            x: bounds.minX + bounds.width * anchor.x,
            y: bounds.minY + bounds.height * anchor.y
        )

        for (index, subview) in subviews.enumerated() {
            let idealSize = subview.sizeThatFits(proposal)
            let minSize = cache.minSizes[index]

            let width = min(bounds.width, max(idealSize.width, minSize.width))
            let height = min(bounds.height, max(idealSize.height, minSize.height))

            let proposal = ProposedViewSize(width: width, height: height)
            subview.place(at: origin, anchor: anchor, proposal: proposal)
        }
    }
}
