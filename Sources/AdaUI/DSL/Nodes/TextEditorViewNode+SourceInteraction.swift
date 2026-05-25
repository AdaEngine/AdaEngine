//
//  TextEditorViewNode+SourceInteraction.swift
//  AdaEngine
//
//  Created by Codex on 24.05.2026.
//

import AdaInput
import Math

extension TextEditorViewNode {

    func handleSourceInteractionMouseEvent(_ event: MouseEvent) -> Bool {
        guard let sourceInteraction else {
            return false
        }

        let localPoint = self.convertPointFromRoot(event.mousePosition)
        let sourcePosition = self.sourcePosition(at: localPoint)

        if event.phase == .began, event.button == .right {
            self.presentSourceContextMenu(at: event.mousePosition, sourcePosition: sourcePosition, interaction: sourceInteraction)
            return true
        }

        if event.modifierKeys.contains(.main) {
            switch event.phase {
            case .changed where event.button == .none:
                self.activateSourceCursorIfNeeded()
                self.notifySourceHover(sourcePosition)
                return true
            case .began where event.button == .left:
                sourceInteraction.onPrimaryClick?(sourcePosition)
                self.notifySourceHover(sourcePosition)
                return true
            case .ended, .cancelled:
                return true
            default:
                break
            }
        } else if event.phase == .changed, event.button == .none {
            self.notifySourceHover(nil)
            self.resetSourceCursorIfNeeded()
        }

        return false
    }

    func notifySourceHover(_ position: TextEditorSourcePosition?) {
        guard self.lastHoveredSourcePosition != position else {
            return
        }

        self.lastHoveredSourcePosition = position
        self.sourceInteraction?.onHover?(position)
    }

    func applyFocusedRangeIfNeeded() {
        let focusedRange = self.sourceInteraction?.focusedRange
        guard focusedRange != self.appliedFocusedRange else {
            return
        }

        self.appliedFocusedRange = focusedRange
        guard let focusedRange else {
            return
        }

        let range = self.rangeOffsets(for: focusedRange)
        self.selectionAnchor = range.lowerBound
        self.selectionHead = range.upperBound
        self.clampSelectionToBounds()
        self.ensureCaretVisibleIfNeeded()
    }

    private func presentSourceContextMenu(
        at location: Point,
        sourcePosition: TextEditorSourcePosition,
        interaction: TextEditorSourceInteraction
    ) {
        guard let provider = interaction.contextMenuItems else {
            return
        }

        let items = provider(sourcePosition)
        guard !items.isEmpty else {
            return
        }

        ContextMenuPresentationCenter.present?(
            ContextMenuPresentation(
                sourceWindow: owner?.window,
                location: location,
                items: items.enumerated().map { index, item in
                    ContextMenuPresentation.Item(
                        id: index,
                        title: item.title,
                        action: item.action,
                        submenu: item.submenu.presentationItems()
                    )
                }
            )
        )
    }
}

private extension [TextEditorContextMenuItem] {
    func presentationItems() -> [ContextMenuPresentation.Item] {
        self.enumerated().map { index, item in
            ContextMenuPresentation.Item(
                id: index,
                title: item.title,
                action: item.action,
                submenu: item.submenu.presentationItems()
            )
        }
    }
}
