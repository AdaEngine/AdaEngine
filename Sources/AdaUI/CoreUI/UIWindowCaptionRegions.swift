import Math

extension UIContainerView {
    /// Collect native caption hit regions in one pass. Clipped content below
    /// the caption cannot contribute, even when a descendant has an offset.
    /// Non-clipping parents must still be searched for overflowing controls.
    func windowCaptionInputRegions(height: Float, window: UIWindow) -> (regions: [Rect], maximizeButton: Rect?) {
        var regions: [Rect] = []
        var maximizeButton: Rect?

        func visit(_ node: ViewNode, parentOrigin: Point) {
            let frame = Rect(origin: parentOrigin + node.frame.origin, size: node.frame.size)
            let intersectsCaption = frame.minY < height && frame.maxY > 0
            if node.isClipping && !intersectsCaption { return }

            // Avoid control/protocol casts for the entire scene, inspector and
            // project tree when only the 32-point caption needs hit testing.
            if intersectsCaption {
                if node.blocksWindowDrag { regions.append(frame) }
                if maximizeButton == nil, node.accessibilityIdentifier == "AdaUI.Caption.Maximize" {
                    maximizeButton = frame
                }
            }
            var childOrigin = frame.origin
            if let scroll = node as? ScrollViewNode { childOrigin -= scroll.contentOffset }
            for child in node.uiChildren() {
                // Inspection can expose a logical child mounted elsewhere.
                // Keep that uncommon case consistent with visualAbsoluteFrame.
                let origin = child.parent === node ? childOrigin
                    : convert(child.visualAbsoluteFrame().origin, to: window) - child.frame.origin
                visit(child, parentOrigin: origin)
            }
        }

        visit(viewTree.rootNode, parentOrigin: convert(.zero, to: window))
        return (regions, maximizeButton)
    }
}
