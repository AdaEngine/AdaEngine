//
//  ImageView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

enum _ImageViewStorage {
    case image(Image)
    case texture(Texture2D)
}

public struct ImageView: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    let storage: _ImageViewStorage
    var isResizable: Bool = false

    public init(_ image: Image) {
        self.storage = .image(image)
    }

    public init(_ texture: Texture2D) {
        self.storage = .texture(texture)
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        ImageViewWidgetNode(storage: self.storage, isResizable: self.isResizable, content: self)
    }
}

public extension ImageView {
    func resizable() -> ImageView {
        var newValue = self
        newValue.isResizable = true
        return newValue
    }
}

class ImageViewWidgetNode: WidgetNode {

    let texture: Texture2D
    let isResizable: Bool

    init<Content: Widget>(storage: _ImageViewStorage, isResizable: Bool, content: Content) {
        switch storage {
        case .image(let image):
            self.texture = Texture2D(image: image)
        case .texture(let texture2D):
            self.texture = texture2D
        }

        self.isResizable = isResizable
        super.init(content: content)
    }

    override func draw(with context: GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        context.drawRect(self.frame, texture: self.texture, color: .white)

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }
}

