import Math
import Observation

/// Custom layouts may read observable geometry without rebuilding their content.
final class ObservedLayoutViewContainerNode: LayoutViewContainerNode {
    private var measurementRevision: UInt64 = 0
    private var placementRevision: UInt64 = 0

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        measurementRevision &+= 1
        let revision = measurementRevision
        return withObservationTracking {
            super.sizeThatFits(proposal)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.measurementRevision == revision else {
                    return
                }
                self.invalidateObservedLayout()
            }
        }
    }

    override func performLayout() {
        placementRevision &+= 1
        let revision = placementRevision
        withObservationTracking {
            super.performLayout()
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.placementRevision == revision else {
                    return
                }
                self.invalidateObservedLayout()
            }
        }
    }

    private func invalidateObservedLayout() {
        markNeedsLayout()
        invalidateNearestLayer()
        owner?.containerView?.setNeedsLayout()
    }
}
