import Math

/// Visible bounds of an interactive control for native hover effects in an embedded surface.
@_spi(Internal)
public struct UIHoverRegion: Hashable {
    public let id: UInt
    public let frame: Rect
}

extension UIContainerView {
    /// Returns clipped control regions without reflecting the entire inspection tree.
    /// Native layers provide gaze effects; input continues through the existing AdaUI hit-test path.
    @_spi(Internal)
    public func uiHoverRegions() -> [UIHoverRegion] {
        layoutIfNeeded()
        var regions: [UIHoverRegion] = []
        let viewport = Rect(origin: .zero, size: bounds.size)
        func walk(_ node: ViewNode) {
            // Editing already has caret/selection feedback; gaze must not wash out the input.
            if node === focusManager.focusedNode, node is TextFieldViewNode || node is TextEditorViewNode {
                return
            }
            let isTap = (node as? GestureAreaViewNode)?.gestures.contains { $0 is TapGestureRecognizer } == true
            if node.canBecomeFocused || isTap, node.environment.isEnabled {
                var rect = node.uiRenderedAbsoluteFrame().intersection(viewport)
                var parent = node.parent
                while let ancestor = parent {
                    if ancestor is ScrollViewNode { rect = rect.intersection(ancestor.uiRenderedAbsoluteFrame()) }
                    parent = ancestor.parent
                }
                if rect.width > 0, rect.height > 0 {
                    regions.append(UIHoverRegion(id: UInt(bitPattern: node.id), frame: rect))
                }
                // A control owns its styled label subtree; avoid duplicate overlapping regions.
                if !isTap {
                    return
                }
            }
            for child in node.uiChildren() { walk(child) }
        }
        walk(viewTree.rootNode)
        return regions
    }
}
