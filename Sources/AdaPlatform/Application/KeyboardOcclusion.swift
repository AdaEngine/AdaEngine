import Math

/// Resolves keyboard coverage in view coordinates, including offscreen hide frames.
struct KeyboardOcclusion: Equatable {
    let frame: Rect
    let height: Float

    init(viewBounds: Rect, keyboardFrame: Rect, isHidden: Bool = false) {
        let left = max(viewBounds.minX, keyboardFrame.minX)
        let top = max(viewBounds.minY, keyboardFrame.minY)
        let right = min(viewBounds.maxX, keyboardFrame.maxX)
        let bottom = min(viewBounds.maxY, keyboardFrame.maxY)
        guard !isHidden, right > left, bottom > top else {
            frame = .zero
            height = 0
            return
        }
        frame = Rect(x: left, y: top, width: right - left, height: bottom - top)
        height = max(0, viewBounds.maxY - top)
    }
}
