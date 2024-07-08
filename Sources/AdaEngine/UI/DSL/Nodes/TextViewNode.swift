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
        if self.textContainer.bounds.size != self.frame.size {
            self.textContainer.bounds = Rect(origin: .zero, size: self.frame.size)
        }
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if proposal == .zero || proposal == .infinity {
            let size = self.layoutManager.boundingSize(width: .infinity, height: .infinity)
            print("calculated text \(self.textContainer.text.text) size for infinty prop:", size)
            return size
        }

        var idealWidth: Float = .infinity
        var idealHeight: Float = .infinity

        if let width = proposal.width, width != .infinity {
            idealWidth = width
        }

        if let height = proposal.height, height != .infinity {
            idealHeight = height
        }

        let size = self.layoutManager.boundingSize(width: idealWidth, height: idealHeight)
        print("calculated text \(self.textContainer.text.text) size for w:\(idealWidth) h:\(idealHeight):", size)
        return size
    }

    override func draw(with context: GUIRenderContext) {
//        context.drawText(in: Rect(origin: .zero, size: self.frame.size), from: self.layoutManager)
        for textLine in self.layoutManager.textLines {
            textLine.draw(at: .zero, context: context)
        }
    }
}
