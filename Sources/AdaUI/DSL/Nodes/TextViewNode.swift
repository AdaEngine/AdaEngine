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
        super.draw(with: context)

        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        // Calculate vertical offset to center text within the frame (render coordinates: +Y is up)
        var verticalOffset: Float = 0
        if !self.layoutManager.textLines.isEmpty {
            // Find the maximum pt (top) and minimum pb (bottom) values among all glyphs
            var maxTopY: Float = -Float.infinity
            var minBottomY: Float = Float.infinity
            
            for line in self.layoutManager.textLines {
                for run in line {
                    for glyph in run {
                        // glyph.position.w is pt (top Y coordinate), glyph.position.y is pb (bottom Y coordinate)
                        maxTopY = max(maxTopY, glyph.position.w)
                        minBottomY = min(minBottomY, glyph.position.y)
                    }
                }
            }
            
            let textCenterY = (maxTopY + minBottomY) / 2
            let frameCenterY = -self.frame.size.height / 2
            verticalOffset = frameCenterY - textCenterY
        }
        
        context.translateBy(x: 0, y: verticalOffset)

        let layout = Text.Layout(lines: self.layoutManager.textLines)
        self.textRenderer.draw(layout: layout, in: &context)
    }

    override func update(from newNode: ViewNode) {
        super.update(from: newNode)

        guard let textNode = newNode as? TextViewNode else {
            return
        }

        self.textRenderer = textNode.textRenderer
        self.textContainer = textNode.textContainer
        self.updateEnvironment(textNode.environment)
    }
}

struct DefaultRichTextRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        for line in layout {
            context.draw(line)
        }
    }
}
