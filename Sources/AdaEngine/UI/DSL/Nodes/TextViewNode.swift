//
//  TextViewNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import Math

final class TextViewNode: ViewNode {

    let textLayoutManager: TextLayoutManager
    private var textContainer: TextContainer {
        didSet {
            self.textLayoutManager.setTextContainer(self.textContainer)
        }
    }

    init(inputs: _ViewInputs, content: Text) {
        let text = content.storage.applyingEnvironment(inputs.environment)
        self.textContainer = TextContainer(text: text)
        self.textLayoutManager = TextLayoutManager()
        self.textLayoutManager.setTextContainer(self.textContainer)
        super.init(content: content)
    }

    override func performLayout() {
        self.textContainer.bounds = Rect(origin: .zero, size: self.frame.size)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero || proposal == .infinity {
            return textLayoutManager.size
        }

        if let width = proposal.width, width > 0 {

        }

        if let height = proposal.height, height > 0 {
            
        }

        return proposal.replacingUnspecifiedDimensions()
    }

    override func draw(with context: GUIRenderContext) {
        context.drawText(in: self.frame, from: self.textLayoutManager)
    }
}
