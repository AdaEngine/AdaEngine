//
//  TextViewNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaText
import Math

final class TextViewNode: ViewNode {

    var layoutManager: TextLayoutManager
    private var textContainer: TextContainer {
        didSet {
            self.layoutManager.setTextContainer(self.textContainer)
            self.layoutManager.invalidateLayout()
            self.sizeCache = [:]
        }
    }

    private var textRenderer: any TextRenderer

    init(inputs: _ViewInputs, content: Text) {
        let text = content.storage.applyingEnvironment(inputs.environment)
        self.textContainer = TextContainer(text: text)
        self.textContainer.numberOfLines = content.storage.lineLimit
        self.layoutManager = TextLayoutManager()
        self.layoutManager.setTextContainer(self.textContainer)
        self.layoutManager.invalidateLayout()
        self.textRenderer = inputs.environment.textRenderer ?? DefaultRichTextRenderer()

        super.init(content: content)
        self.updateEnvironment(inputs.environment)
    }

    /// Cache the sizes while layoutmanager is consistent.
    /// If layout manager did change, we should drop cache sizes.
    private var sizeCache: [ProposedViewSize: Size] = [:]

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if let size = sizeCache[proposal] {
            return size
        }

        let size = self.textRenderer.sizeThatFits(
            proposal: proposal,
            text: Text.Proxy(layoutManager: self.layoutManager)
        )

        self.sizeCache[proposal] = size
        return size
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = environment
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
        
        // Calculate vertical offset to position text correctly within the frame
        // Text positions are calculated relative to y=0, but we need to offset them down
        // to account for the top of the first line (which may have positive pt values)
        var verticalOffset: Float = 0
        if let firstLine = self.layoutManager.textLines.first, !self.layoutManager.textLines.isEmpty {
            // Find the maximum pt (top) value among all glyphs in the first line
            var maxTopY: Float = 0
            for run in firstLine {
                for glyph in run {
                    // glyph.position.w is pt (top Y coordinate)
                    maxTopY = max(maxTopY, glyph.position.w)
                }
            }
            // Offset down by the maximum top Y to position text correctly
            verticalOffset = -maxTopY
        }
        
        context.translateBy(x: 0, y: verticalOffset)
        
        let layout = Text.Layout(lines: self.layoutManager.textLines)
        self.textRenderer.draw(layout: layout, in: &context)

        super.draw(with: context)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let textNode = newNode as? TextViewNode else {
            return
        }

        self.textRenderer = textNode.textRenderer
        self.textContainer = textNode.textContainer
        self.updateEnvironment(textNode.environment)
        
//        self.invalidateLayerIfNeeded()
    }
}

struct DefaultRichTextRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        for line in layout {
            context.draw(line)
        }
    }
}
