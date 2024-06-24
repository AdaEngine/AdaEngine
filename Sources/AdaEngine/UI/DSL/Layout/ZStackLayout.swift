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
        subviews.forEach { subview in
            cache.minSizes.append(subview.sizeThatFits(.zero))
            cache.maxSizes.append(subview.sizeThatFits(.infinity))
        }
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> Size {
        return .zero
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {

    }
}
