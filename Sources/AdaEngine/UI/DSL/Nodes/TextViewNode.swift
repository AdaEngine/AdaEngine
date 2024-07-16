//
//  TextViewNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

final class TextViewNode: ViewNode {

    let layoutManager: TextLayoutManager
    private var textContainer: TextContainer {
        didSet {
            self.layoutManager.setTextContainer(self.textContainer)
            self.layoutManager.invalidateLayout()
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

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        self.textRenderer.sizeThatFits(
            proposal: proposal,
            text: Text.Proxy(layoutManager: self.layoutManager)
        )
    }

    override func merge(_ otherNode: ViewNode) {
        super.merge(otherNode)

        guard let textNode = otherNode as? TextViewNode else {
            return
        }

        self.textRenderer = textNode.textRenderer
    }

    override func draw(with context: UIGraphicsContext) {
        var context = context
        context.environment = self.environment

        let layout = Text.Layout(lines: self.layoutManager.textLines)
        self.textRenderer.draw(layout: layout, in: &context)
    }
}

struct DefaultRichTextRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        for line in layout {
            context.draw(line)
        }
    }
}
