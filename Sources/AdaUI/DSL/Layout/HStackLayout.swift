//
//  HStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import Math

public struct StackLayoutCache {
    var minSizes: [Size] = []
    var maxSizes: [Size] = []

    var minSize: Size = .zero
    var maxSize: Size = .zero

    var totalSubviewSpacing: Float = .zero
    var subviewSpacings: [Float] = []
}

public struct HStackLayout: Layout {

    public typealias AnimatableData = EmptyAnimatableData

    let alignment: VerticalAlignment
    let spacing: Float?

    public init(alignment: VerticalAlignment = .center, spacing: Float?) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public typealias Cache = StackLayoutCache

    public static var layoutProperties: LayoutProperties = LayoutProperties(stackOrientation: .horizontal)

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
            return Size(width: cache.minSize.width + cache.totalSubviewSpacing, height: size.height)
        }

        let idealSize = subviews.reduce(Size.zero) { partialResult, subview in
            var newSize = partialResult
            let idealSize = subview.sizeThatFits(ProposedViewSize(height: size.height))
            newSize.width += idealSize.width
            newSize.height = max(partialResult.height, proposal.height ?? idealSize.height)
            return newSize
        }

        if proposal.width == nil {
            return Size(width: idealSize.width + cache.totalSubviewSpacing, height: idealSize.height)
        }

        let width = min(max(idealSize.width, size.width - cache.totalSubviewSpacing), cache.maxSize.width)

        return Size(
            width: width + cache.totalSubviewSpacing,
            height: idealSize.height
        )
    }

    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let size = proposal.replacingUnspecifiedDimensions()

        var origin: Point = bounds.origin
        var anchor: AnchorPoint = .leading
        
        switch self.alignment {
        case .top:
            anchor = .topLeading
            origin.y = bounds.minY
        case .bottom:
            anchor = .bottomLeading
            origin.y = bounds.maxY
        case .center:
            anchor = .leading
            origin.y = bounds.midY
        }
        var idealWidth: Float = 0
        let idealSizes: [Size] = subviews.map { subview in
            let size = subview.sizeThatFits(ProposedViewSize(height: size.height))
            idealWidth += size.width
            return size
        }

        let layoutWidth = min(cache.maxSize.width + cache.totalSubviewSpacing, bounds.width)
        origin.x += (bounds.width - layoutWidth) * 0.5

        var restOfFlexibleViews = zip(cache.maxSizes, idealSizes).reduce(Int.zero) { count, sizes in
            return count + (sizes.0.width > sizes.1.width ? 1 : 0)
        }

        var availableSpace = max(layoutWidth - idealWidth - cache.totalSubviewSpacing, 0)

        for (index, subview) in subviews.enumerated() {
            var idealWidth = idealSizes[index].width
            let maxWidth = cache.maxSizes[index].width

            let isFlexible = idealWidth < maxWidth

            if isFlexible && restOfFlexibleViews > 0 {
                let slot = max(availableSpace, 0) / Float(restOfFlexibleViews)
                idealWidth += slot
                availableSpace -= slot
                restOfFlexibleViews -= 1
            }

            origin.x += cache.subviewSpacings[index]

            let proposal = ProposedViewSize(width: idealWidth, height: bounds.height)
            subview.place(at: origin, anchor: anchor, proposal: proposal)

            let newWidth = subview.dimensions(in: proposal).width

            if isFlexible {
                availableSpace -= newWidth - idealWidth
            }

            origin.x += newWidth
        }
    }

}
