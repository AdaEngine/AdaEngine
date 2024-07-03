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
        }
    }

    init(inputs: _ViewInputs, content: Text) {
        let text = content.storage.applyingEnvironment(inputs.environment)
        self.textContainer = TextContainer(text: text)
        self.layoutManager = TextLayoutManager()
        self.layoutManager.setTextContainer(self.textContainer)
        super.init(content: content)
    }

    override func performLayout() {
        self.textContainer.bounds = Rect(origin: .zero, size: self.frame.size)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero || proposal == .infinity {
            return layoutManager.size
        }

        var idealWidth: Float = 0
        var idealHeight: Float = 0
        if let width = proposal.width, width != .infinity {

        }

        if let height = proposal.height, height != .infinity {

        }

        return proposal.replacingUnspecifiedDimensions()
    }

    override func draw(with context: GUIRenderContext) {
        context.drawText(in: self.frame, from: self.layoutManager)
    }
}
