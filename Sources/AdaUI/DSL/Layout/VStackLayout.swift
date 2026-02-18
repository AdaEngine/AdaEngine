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
        if proposal == .zero {
            let minWidth = cache.minSizes.reduce(Float.zero) { max($0, $1.width) }
            return Size(width: minWidth, height: cache.minSize.height + cache.totalSubviewSpacing)
        }

        let proposedWidth = finiteDimension(proposal.width)
        let idealSizes = subviews.enumerated().map { index, subview in
            let measured = subview.sizeThatFits(ProposedViewSize(width: proposedWidth))
            return sanitized(size: measured, fallback: cache.minSizes[index])
        }
        let idealSize = idealSizes.reduce(Size.zero) { partialResult, subviewSize in
            Size(
                width: max(partialResult.width, subviewSize.width),
                height: partialResult.height + subviewSize.height
            )
        }
        let hasFlexibleSubviews = (0..<subviews.count).contains { index in
            isFlexibleSubview(index: index, idealSizes: idealSizes, cache: cache)
        }

        guard let proposedHeight = finiteDimension(proposal.height), hasFlexibleSubviews else {
            return Size(width: idealSize.width, height: idealSize.height + cache.totalSubviewSpacing)
        }

        let height = min(max(idealSize.height, proposedHeight - cache.totalSubviewSpacing), cache.maxSize.height)
        return Size(
            width: idealSize.width,
            height: height + cache.totalSubviewSpacing
        )
    }

    public func placeSubviews(in bounds: Math.Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
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
        let proposedWidth = finiteDimension(proposal.width)
        let idealSizes: [Size] = subviews.enumerated().map { index, subview in
            let measured = subview.sizeThatFits(ProposedViewSize(width: proposedWidth))
            let sanitizedSize = sanitized(size: measured, fallback: cache.minSizes[index])
            idealHeight += sanitizedSize.height
            return sanitizedSize
        }
        let hasFlexibleSubviews = (0..<subviews.count).contains { index in
            isFlexibleSubview(index: index, idealSizes: idealSizes, cache: cache)
        }

        let layoutHeight: Float
        if hasFlexibleSubviews {
            layoutHeight = min(cache.maxSize.height + cache.totalSubviewSpacing, bounds.height)
        } else {
            layoutHeight = min(idealHeight + cache.totalSubviewSpacing, bounds.height)
        }
        origin.y += (bounds.height - layoutHeight) * 0.5

        var restOfFlexibleViews = (0..<subviews.count).reduce(Int.zero) { count, index in
            return count + (isFlexibleSubview(index: index, idealSizes: idealSizes, cache: cache) ? 1 : 0)
        }

        var availableSpace = max(layoutHeight - idealHeight - cache.totalSubviewSpacing, 0)

        for (index, subview) in subviews.enumerated() {
            var idealHeight = idealSizes[index].height
            let isFlexible = isFlexibleSubview(index: index, idealSizes: idealSizes, cache: cache)

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

    @inline(__always)
    private func finiteDimension(_ value: Float?) -> Float? {
        guard let value, value.isFinite else {
            return nil
        }

        return value
    }

    @inline(__always)
    private func sanitized(size: Size, fallback: Size) -> Size {
        Size(
            width: size.width.isFinite ? size.width : fallback.width,
            height: size.height.isFinite ? size.height : fallback.height
        )
    }

    @inline(__always)
    private func isFlexibleSubview(
        index: Int,
        idealSizes: [Size],
        cache: Cache
    ) -> Bool {
        let maxHeight = cache.maxSizes[index].height
        let idealHeight = idealSizes[index].height
        let minHeight = cache.minSizes[index].height
        return maxHeight > idealHeight && minHeight == idealHeight
    }
}
