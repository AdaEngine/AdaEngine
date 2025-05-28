//
//  UILabel.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 14.06.2024.
//

import AdaText

@MainActor
open class UILabel: UIView {

    public var text: String = "" {
        didSet {
            updateTextLayoutManager()
        }
    }

    public var textColor: Color = .white {
        didSet {
            updateTextLayoutManager()
        }
    }

    public var font: Font = .system(size: 17) {
        didSet {
            updateTextLayoutManager()
        }
    }

    public var attributedString: AttributedText? {
        didSet {
            updateTextLayoutManager()
        }
    }

    private var textContainer = TextContainer()
    private var textLayout = TextLayoutManager()

    open override func draw(in rect: Rect, with context: UIGraphicsContext) {
        context.drawText(in: rect, from: self.textLayout)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        self.textLayout.setTextContainer(self.textContainer)
        self.textLayout.fitToSize(self.frame.size)
    }

    private func updateTextLayoutManager() {
        if let attributedString = attributedString {
            self.textContainer.text = attributedString
        } else {
            var container = TextAttributeContainer()
            container.font = self.font
            container.foregroundColor = self.textColor
            let attributedString = AttributedText(self.text, attributes: container)
            self.textContainer.text = attributedString
        }

        self.textLayout.setTextContainer(self.textContainer)
        self.textLayout.invalidateLayout()
    }

}
