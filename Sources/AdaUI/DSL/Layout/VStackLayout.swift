//
//  VStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct VStackLayout: Layout {

    public typealias AnimatableData = EmptyAnimatableData

    let alignment: HorizontalAlignment
    let spacing: Float?

    public init(alignment: HorizontalAlignment = .center, spacing: Float? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public typealias Cache = StackLayoutCache

    public static var layoutProperties: LayoutProperties = LayoutProperties(stackOrientation: .vertical)

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
        let size = proposal.replacingUnspecifiedDimensions()

        if proposal == .zero {
            return Size(width: size.width, height: cache.minSize.height + cache.totalSubviewSpacing)
        }

        let idealSize = subviews.reduce(Size.zero) { partialResult, subview in
            var newSize = partialResult
            let idealSize = subview.sizeThatFits(ProposedViewSize(width: size.width))
            newSize.width = max(partialResult.width, proposal.width ?? idealSize.width)
            newSize.height += idealSize.height
            return newSize
        }

        if proposal.height == nil {
            return Size(width: idealSize.width, height: idealSize.height + cache.totalSubviewSpacing)
        }

        let height = min(max(idealSize.height, size.height - cache.totalSubviewSpacing), cache.maxSize.height)
        return Size(
            width: idealSize.width,
            height: height + cache.totalSubviewSpacing
        )
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let size = proposal.replacingUnspecifiedDimensions()
        
        var origin: Point = bounds.origin
        var anchor: AnchorPoint = .leading

        switch self.alignment {
        case .leading:
            anchor = .topLeading
            origin.x = bounds.minX
        case .trailing:
            anchor = .topTrailing
            origin.x = bounds.maxX
        case .center:
            anchor = .top
            origin.x = bounds.midX
        }
        var idealHeight: Float = 0
        let idealSizes: [Size] = subviews.map { subview in
            let size = subview.sizeThatFits(ProposedViewSize(width: size.width))
            idealHeight += size.height
            return size
        }

        let layoutHeight = min(cache.maxSize.height + cache.totalSubviewSpacing, bounds.height)
        origin.y += (bounds.height - layoutHeight) * 0.5

        var restOfFlexibleViews = zip(cache.maxSizes, idealSizes).reduce(Int.zero) { count, sizes in
            return count + (sizes.0.height > sizes.1.height ? 1 : 0)
        }

        var availableSpace = max(layoutHeight - idealHeight - cache.totalSubviewSpacing, 0)

        for (index, subview) in subviews.enumerated() {
            var idealHeight = idealSizes[index].height
            let maxHeight = cache.maxSizes[index].height

            let isFlexible = idealHeight < maxHeight

            if isFlexible && restOfFlexibleViews > 0 {
                let slot = max(availableSpace, 0) / Float(restOfFlexibleViews)
                idealHeight += slot
                availableSpace -= slot
                restOfFlexibleViews -= 1
            }

            origin.y += cache.subviewSpacings[index]

            let proposal = ProposedViewSize(width: bounds.width, height: idealHeight)
            subview.place(at: origin, anchor: anchor, proposal: proposal)

            let newHeight = subview.dimensions(in: proposal).height

            if isFlexible {
                availableSpace -= newHeight - idealHeight
            }

            origin.y += newHeight
        }
    }
}
