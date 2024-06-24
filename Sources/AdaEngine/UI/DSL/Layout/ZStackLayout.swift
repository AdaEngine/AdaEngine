//
//  ZStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct ZStackLayout: Layout {
    public typealias Cache = StackLayoutCache

    public func makeCache(subviews: Subviews) -> Cache {
        var cache = StackLayoutCache()
        self.updateCache(&cache, subviews: subviews)
        return cache
    }

    public func updateCache(_ cache: inout StackLayoutCache, subviews: Subviews) {
        cache = StackLayoutCache()

        for (index, subview) in subviews.enumerated() {
            let minSize = subview.sizeThatFits(.zero)
            let maxSize = subview.sizeThatFits(.infinity)

            cache.minSizes.append(minSize)
            cache.minSize += minSize
            cache.maxSizes.append(maxSize)
            cache.maxSize += maxSize

            if index != subviews.startIndex && index != subviews.endIndex {
                let space = self.spacing ?? 8
                cache.totalSubviewSpacing += space
                cache.subviewSpacings.append(space)
            } else {
                cache.subviewSpacings.append(0)
            }
        }
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size {
        return .zero
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {

    }
}
