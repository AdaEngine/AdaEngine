//
//  TextEditorViewNode.swift
//  AdaEngine
//
//  Created by Codex on 18.05.2026.
//

import AdaInput
import AdaRender
import AdaUtils
import Math

final class TextEditorViewNode: ViewNode {

    struct Snapshot: Equatable {
        var text: String
        var selectionAnchor: Int
        var selectionHead: Int
    }

    struct TextPosition: Equatable {
        var line: Int
        var column: Int
    }

    struct LineInfo {
        var text: String
        var startOffset: Int
    }

    enum Constants {
        static let horizontalInset: Float = 10
        static let verticalInset: Float = 8
        static let gutterWidth: Float = 52
        static let gutterSpacing: Float = 10
        static let minimumWidth: Float = 260
        static let minimumHeight: Float = 120
        static let placeholderOpacity: Float = 0.45
        static let maxUndoDepth = 128
        static let caretLineWidth: Float = 1.5
        static let caretBlinkInterval: AdaUtils.TimeInterval = 1.15
        static let tapMovementToleranceSquared: Float = 36
        static let scrollWheelScale: Float = 100
    }

    var placeholder: String
    var textBinding: Binding<String>
    var text: String

    var isFocused = false
    var isSelectingWithMouse = false
    var mousePressStartPoint: Point?
    var scrollOffset: Point = .zero
    var preferredColumn: Int?
    var caretVisible = true
    var caretBlinkElapsed: AdaUtils.TimeInterval = 0
    var selectionAnchor = 0
    var selectionHead = 0

    var undoStack: [Snapshot] = []
    var redoStack: [Snapshot] = []

    init(inputs: _ViewInputs, content: TextEditor) {
        self.placeholder = content.placeholder
        self.textBinding = content.text
        self.text = Self.normalizeInputText(content.text.wrappedValue)
        super.init(content: content)
        self.updateEnvironment(inputs.environment)
        self.clampSelectionToBounds()
    }

    override var canBecomeFocused: Bool {
        true
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let pointSize = self.resolvedFontPointSize()
        let lineHeight = self.lineHeight(for: pointSize)
        let maxLineWidth = Float(self.lines().map(\.text.count).max() ?? max(self.placeholder.count, 1)) * self.characterAdvance(for: pointSize)
        let ideal = Size(
            width: max(Constants.minimumWidth, Constants.horizontalInset * 2 + Constants.gutterWidth + Constants.gutterSpacing + maxLineWidth),
            height: max(Constants.minimumHeight, Constants.verticalInset * 2 + lineHeight * 6)
        )

        var result = proposal.replacingUnspecifiedDimensions(by: ideal)
        if result.width == .infinity {
            result.width = ideal.width
        }
        if result.height == .infinity {
            result.height = ideal.height
        }

        return result
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let node = newNode as? TextEditorViewNode else {
            return
        }

        self.placeholder = node.placeholder
        self.textBinding = node.textBinding

        let externalText = Self.normalizeInputText(node.textBinding.wrappedValue)
        if externalText != self.text {
            self.text = externalText
            self.undoStack.removeAll(keepingCapacity: true)
            self.redoStack.removeAll(keepingCapacity: true)
        }

        self.clampSelectionToBounds()
        self.ensureCaretVisibleIfNeeded()
        self.requestDisplay()
    }

    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        guard self.point(inside: point, with: event) else {
            return nil
        }
        return self
    }

    override func onFocusChanged(isFocused: Bool) {
        self.isFocused = isFocused
        if !isFocused {
            self.isSelectingWithMouse = false
            self.mousePressStartPoint = nil
        }
        self.caretVisible = isFocused
        self.caretBlinkElapsed = 0
        self.owner?.window?.windowManager.textInputFocusDidChange(isFocused)
        self.requestDisplay()
    }

    override func onMouseEvent(_ event: MouseEvent) {
        if event.button == .scrollWheel {
            self.scroll(by: Point(event.scrollDelta.x * Constants.scrollWheelScale, event.scrollDelta.y * Constants.scrollWheelScale))
            return
        }

        self.owner?.window?.windowManager.setCursorShape(.iBeam)

        let shouldHandleSelectionEvent: Bool = switch event.phase {
        case .began, .ended, .cancelled:
            event.button == .left
        case .changed:
            event.button == .left || self.isSelectingWithMouse
        }

        guard shouldHandleSelectionEvent else {
            return
        }

        let localPoint = self.convertPointFromRoot(event.mousePosition)
        let caretOffset = self.closestOffset(to: localPoint)

        switch event.phase {
        case .began:
            self.isSelectingWithMouse = true
            self.mousePressStartPoint = localPoint
            if event.modifierKeys.contains(.shift), self.isFocused {
                self.selectionHead = caretOffset
            } else {
                self.setSelection(to: caretOffset)
            }
            self.preferredColumn = nil
        case .changed:
            guard self.isSelectingWithMouse else {
                return
            }
            self.selectionHead = caretOffset
            self.preferredColumn = nil
        case .ended, .cancelled:
            self.isSelectingWithMouse = false
            if !self.isTap(at: localPoint, start: self.mousePressStartPoint) {
                self.selectionHead = caretOffset
            }
            self.mousePressStartPoint = nil
            self.preferredColumn = nil
        }

        self.clampSelectionToBounds()
        self.ensureCaretVisibleIfNeeded()
        self.resetCaretBlink()
        self.requestDisplay()
    }

    override func onMouseLeave() {
        self.owner?.window?.windowManager.setCursorShape(.arrow)
    }

    override func onTextInputEvent(_ event: TextInputEvent) {
        guard self.isFocused else {
            return
        }

        switch event.action {
        case .insert:
            self.insertText(event.text)
        case .deleteBackward:
            self.deleteBackward()
        }

        self.preferredColumn = nil
        self.resetCaretBlink()
    }

    override func onKeyEvent(_ event: KeyEvent) {
        guard self.isFocused, event.status == .down else {
            return
        }

        if self.handleShortcut(event) {
            self.resetCaretBlink()
            return
        }

        let extendSelection = event.modifiers.contains(.shift)
        let movesByWordBoundary = event.modifiers.contains(.main)

        switch event.keyCode {
        case .enter:
            self.insertText("\n")
        case .tab:
            self.insertText("    ")
        case .arrowLeft:
            if movesByWordBoundary {
                self.moveCaretByWordBoundary(direction: -1, extendSelection: extendSelection)
            } else {
                self.moveCaretHorizontally(delta: -1, extendSelection: extendSelection)
            }
        case .arrowRight:
            if movesByWordBoundary {
                self.moveCaretByWordBoundary(direction: 1, extendSelection: extendSelection)
            } else {
                self.moveCaretHorizontally(delta: 1, extendSelection: extendSelection)
            }
        case .arrowUp:
            self.moveCaretVertically(delta: -1, extendSelection: extendSelection)
        case .arrowDown:
            self.moveCaretVertically(delta: 1, extendSelection: extendSelection)
        case .home:
            if movesByWordBoundary {
                self.moveCaretToDocumentStart(extendSelection: extendSelection)
            } else {
                self.moveCaretToLineStart(extendSelection: extendSelection)
            }
        case .pageUp:
            self.moveCaretByPage(delta: -1, extendSelection: extendSelection)
        case .pageDown:
            self.moveCaretByPage(delta: 1, extendSelection: extendSelection)
        case .delete:
            self.deleteForward()
        default:
            return
        }

        self.resetCaretBlink()
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        guard self.isFocused else {
            return
        }

        self.caretBlinkElapsed += deltaTime
        guard self.caretBlinkElapsed >= Constants.caretBlinkInterval else {
            return
        }

        self.caretBlinkElapsed.formTruncatingRemainder(dividingBy: Constants.caretBlinkInterval)
        self.caretVisible.toggle()
        if !self.hasSelection {
            self.requestDisplay()
        }
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        super.draw(with: context)

        let bounds = Rect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        let contentRect = self.textContentRect()
        let textRect = self.textRect()
        let pointSize = self.resolvedFontPointSize()
        let lineHeight = self.lineHeight(for: pointSize)
        let editorColors = self.environment.textEditorColors
        let borderColor = self.isFocused ? editorColors.focusedBorder : editorColors.border

        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        context.drawRect(bounds, color: editorColors.background)
        self.drawBorder(in: &context, rect: bounds, color: borderColor)

        guard contentRect.width > 0, contentRect.height > 0 else {
            return
        }

        context.drawLine(
            start: Point(textRect.origin.x - Constants.gutterSpacing * 0.5, -contentRect.minY),
            end: Point(textRect.origin.x - Constants.gutterSpacing * 0.5, -contentRect.maxY),
            lineWidth: 1,
            color: editorColors.gutterRule
        )

        let clipRect = self.visualAbsoluteContentRect()
        context.clip(to: clipRect) { clippedContext in
            var clippedContext = clippedContext
            let visibleLines = self.visibleLineRange(lineHeight: lineHeight, viewportHeight: contentRect.height)
            let lines = self.lines()
            let caretPosition = self.position(forOffset: self.selectionHead, lines: lines)
            let textColor = self.resolvedTextColor()
            let resolvedFont = self.resolvedFontForRendering()

            for lineIndex in visibleLines where lines.indices.contains(lineIndex) {
                let line = lines[lineIndex]
                let rowY = contentRect.origin.y + Float(lineIndex) * lineHeight - self.scrollOffset.y
                let rowRect = Rect(x: contentRect.minX, y: rowY, width: contentRect.width, height: lineHeight)

                if self.isFocused, caretPosition.line == lineIndex {
                    clippedContext.drawRect(rowRect, color: editorColors.currentLineBackground)
                }

                self.drawSelectionIfNeeded(
                    in: &clippedContext,
                    line: line,
                    lineIndex: lineIndex,
                    rowY: rowY,
                    lineHeight: lineHeight,
                    pointSize: pointSize
                )

                if let resolvedFont {
                    let number = String(lineIndex + 1)
                    self.drawString(
                        number,
                        font: resolvedFont,
                        color: editorColors.gutter,
                        in: &clippedContext,
                        at: Point(contentRect.minX + Constants.gutterWidth - Float(number.count) * self.characterAdvance(for: pointSize), rowY)
                    )
                    self.drawString(
                        line.text,
                        font: resolvedFont,
                        color: textColor,
                        in: &clippedContext,
                        at: Point(textRect.minX - self.scrollOffset.x, rowY)
                    )
                }
            }

            if self.text.isEmpty, !self.placeholder.isEmpty, !self.isFocused, let resolvedFont {
                self.drawString(
                    self.placeholder,
                    font: resolvedFont,
                    color: textColor.opacity(Constants.placeholderOpacity),
                    in: &clippedContext,
                    at: Point(textRect.minX, contentRect.minY)
                )
            }

            if self.isFocused, self.caretVisible, !self.hasSelection {
                let caretX = textRect.minX + Float(caretPosition.column) * self.characterAdvance(for: pointSize) - self.scrollOffset.x
                let caretY = contentRect.minY + Float(caretPosition.line) * lineHeight - self.scrollOffset.y
                clippedContext.drawRect(
                    Rect(
                        x: caretX - Constants.caretLineWidth * 0.5,
                        y: caretY,
                        width: Constants.caretLineWidth,
                        height: lineHeight
                    ),
                    color: self.environment.accentColor
                )
            }
        }
    }
}
