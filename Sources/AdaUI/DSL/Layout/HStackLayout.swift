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

            if index != subviews.startIndex {
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
            let minHeight = cache.minSizes.reduce(Float.zero) { max($0, $1.height) }
            return Size(width: cache.minSize.width + cache.totalSubviewSpacing, height: minHeight)
        }

        let proposedHeight = finiteDimension(proposal.height)
        let idealSizes = subviews.enumerated().map { index, subview in
            let measured = subview.sizeThatFits(ProposedViewSize(height: proposedHeight))
            return sanitized(size: measured, fallback: cache.minSizes[index])
        }
        let idealSize = idealSizes.reduce(Size.zero) { partialResult, subviewSize in
            Size(
                width: partialResult.width + subviewSize.width,
                height: max(partialResult.height, subviewSize.height)
            )
        }
        let hasFlexibleSubviews = zip(cache.maxSizes, idealSizes).contains { maxSize, idealSize in
            maxSize.width > idealSize.width
        }

        guard let proposedWidth = finiteDimension(proposal.width), hasFlexibleSubviews else {
            return Size(width: idealSize.width + cache.totalSubviewSpacing, height: idealSize.height)
        }

        let width = min(max(idealSize.width, proposedWidth - cache.totalSubviewSpacing), cache.maxSize.width)

        return Size(
            width: width + cache.totalSubviewSpacing,
            height: idealSize.height
        )
    }

    public func placeSubviews(in bounds: Rect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
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
        let proposedHeight = finiteDimension(proposal.height)
        let idealSizes: [Size] = subviews.enumerated().map { index, subview in
            let size = subview.sizeThatFits(ProposedViewSize(height: proposedHeight))
            let sanitizedSize = sanitized(size: size, fallback: cache.minSizes[index])
            idealWidth += sanitizedSize.width
            return sanitizedSize
        }
        let hasFlexibleSubviews = zip(cache.maxSizes, idealSizes).contains { maxSize, idealSize in
            maxSize.width > idealSize.width
        }

        let layoutWidth: Float
        if hasFlexibleSubviews {
            layoutWidth = min(cache.maxSize.width + cache.totalSubviewSpacing, bounds.width)
        } else {
            layoutWidth = min(idealWidth + cache.totalSubviewSpacing, bounds.width)
        }
        origin.x += (bounds.width - layoutWidth) * 0.5

        var restOfFlexibleViews = (0..<subviews.count).reduce(Int.zero) { count, index in
            let maxWidth = cache.maxSizes[index].width
            let idealWidth = idealSizes[index].width
            let isFlexible = maxWidth > idealWidth
            return count + (isFlexible ? 1 : 0)
        }

        var availableSpace = max(layoutWidth - idealWidth - cache.totalSubviewSpacing, 0)

        for (index, subview) in subviews.enumerated() {
            var idealWidth = idealSizes[index].width
            let maxWidth = cache.maxSizes[index].width

            let isFlexible = maxWidth > idealWidth

            if isFlexible && restOfFlexibleViews > 0 {
                let slot = max(availableSpace, 0) / Float(restOfFlexibleViews)
                idealWidth += slot
                availableSpace -= slot
                restOfFlexibleViews -= 1
            }

            origin.x += cache.subviewSpacings[index]

            let proposal = ProposedViewSize(width: idealWidth, height: idealSizes[index].height)
            subview.place(at: origin, anchor: anchor, proposal: proposal)

            let newWidth = subview.dimensions(in: proposal).width

            if isFlexible {
                availableSpace -= newWidth - idealWidth
            }

            origin.x += newWidth
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

}
