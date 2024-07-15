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
        self.textContainer.numberOfLines = content.storage.lineLimit
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
            let size = self.layoutManager.boundingSize()
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

        let size = self.layoutManager.boundingSize()
        return Size(
            width: min(idealWidth, size.width),
            height: min(idealHeight, size.height)
        )
    }

    override func draw(with context: UIGraphicsContext) {
        for textLine in self.layoutManager.textLines {
            textLine.draw(at: self.frame.origin, context: context)
        }
    }
}
