//
//  UIButton.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.06.2024.
//

import AdaText

open class UIButton: UIControl {

    private struct ButtonStyle {
        var icon: Texture2D?
        var backgroundColor: Color?
        var textContainer = TextContainer(text: "Button") {
            didSet {
                textLayout.setTextContainer(self.textContainer)
            }
        }

        let textLayout = TextLayoutManager()
    }

    private var styles: [State: ButtonStyle] = [:]

    // MARK: - Style Configuration

    public func setIcon(_ texture: Texture2D?, for state: State) {
        self.styles[state, default: ButtonStyle()].icon = texture
    }

    public func setBackgroundColor(_ color: Color, for state: State) {
        self.styles[state, default: ButtonStyle()].backgroundColor = color
    }

    public func setAttributedText(_ text: AttributedText, for state: State) {
        self.styles[state, default: ButtonStyle()].textContainer.text = text
    }

    open override func draw(in rect: Rect, with context: UIGraphicsContext) {
        let style = self.styles[self.state]
        let color = style?.backgroundColor ?? self.backgroundColor
        context.drawRect(rect, color: color)

        if let textLayout = style?.textLayout {
            context.drawText(in: rect, from: textLayout)
        }

        if let texture = style?.icon {
            context.drawRect(rect, texture: texture, color: .white)
        }
    }

    open override func onMouseEvent(_ event: MouseEvent) {
        if !self.state.isEnabled {
            return
        }

        super.onMouseEvent(event)

        switch event.phase {
        case .began:
            self.triggerActions(for: .touchDown)
        case .changed:
            self.triggerActions(for: .touchDragInside)
        case .ended:
            self.triggerActions(for: .touchUp)
        case .cancelled:
            self.triggerActions(for: .touchCancel)
        }
    }
}
