//
//  VStackLayout.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.06.2024.
//

import AdaAnimation
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

            if index != 0 {
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
            isFlexibleSubview(index: index, cache: cache)
        }

        guard let proposedHeight = finiteDimension(proposal.height), hasFlexibleSubviews else {
            return Size(width: idealSize.width, height: idealSize.height + cache.totalSubviewSpacing)
        }

        let maximumContentHeight = max(cache.maxSize.height, idealSize.height)
        let height = min(max(idealSize.height, proposedHeight - cache.totalSubviewSpacing), maximumContentHeight)

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
            isFlexibleSubview(index: index, cache: cache)
        }

        let layoutHeight: Float
        if hasFlexibleSubviews {
            let maximumLayoutHeight = max(cache.maxSize.height, idealHeight) + cache.totalSubviewSpacing
            layoutHeight = min(maximumLayoutHeight, bounds.height)
        } else {
            layoutHeight = min(idealHeight + cache.totalSubviewSpacing, bounds.height)
        }
        let preferredFlexibleIndices = (0..<subviews.count).filter { index in
            isFlexibleSubview(index: index, cache: cache) && !isSpacerSubview(subviews[index])
        }
        let fallbackFlexibleIndices = (0..<subviews.count).filter { index in
            isFlexibleSubview(index: index, cache: cache)
        }

        let distributedFlexibleIndices = preferredFlexibleIndices.isEmpty
            ? fallbackFlexibleIndices
            : preferredFlexibleIndices

        let layoutPriorities = subviews.map(\.layoutPriority)
        let distributedPriorityCount = Set(distributedFlexibleIndices.map { layoutPriorities[$0] }).count

        if distributedPriorityCount > 1 {
            let assignedHeights = stackAssignedMainAxisSizes(
                idealSizes: idealSizes.map(\.height),
                minSizes: cache.minSizes.map(\.height),
                maxSizes: cache.maxSizes.map(\.height),
                layoutPriorities: layoutPriorities,
                flexibleIndices: distributedFlexibleIndices,
                availableSpace: layoutHeight - idealHeight - cache.totalSubviewSpacing
            )

            for (index, subview) in subviews.enumerated() {
                let assignedHeight = assignedHeights[index]

                origin.y += cache.subviewSpacings[index]

                let proposal = ProposedViewSize(width: bounds.width, height: assignedHeight)
                subview.place(at: origin, anchor: anchor, proposal: proposal)

                let newHeight = subview.dimensions(in: proposal).height
                origin.y += newHeight
            }
        } else {
            let equalizedSpacerHeights = equalizedSpacerMainAxisSizes(
                idealSizes: idealSizes.map(\.height),
                maxSizes: cache.maxSizes.map(\.height),
                spacerIndices: distributedFlexibleIndices.filter { isSpacerSubview(subviews[$0]) },
                availableSpace: max(layoutHeight - idealHeight - cache.totalSubviewSpacing, 0)
            )
            var restOfFlexibleViews = distributedFlexibleIndices.count
            var availableSpace = max(layoutHeight - idealHeight - cache.totalSubviewSpacing, 0)

            for (index, subview) in subviews.enumerated() {
                var idealHeight = equalizedSpacerHeights?[index] ?? idealSizes[index].height
                let isFlexible = isFlexibleSubview(index: index, cache: cache)
                let participatesInDistribution = distributedFlexibleIndices.contains(index)

                if equalizedSpacerHeights == nil && isFlexible && participatesInDistribution && restOfFlexibleViews > 0 {
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
        cache: Cache
    ) -> Bool {
        let maxHeight = cache.maxSizes[index].height
        let minHeight = cache.minSizes[index].height
        return maxHeight > minHeight
    }

    @inline(__always)
    private func isSpacerSubview(_ subview: LayoutSubview) -> Bool {
        subview.node is SpacerViewNode
    }
}
