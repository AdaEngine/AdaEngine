//
//  ImageView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math


public struct ImageView: View, ViewNodeBuilder {

    public enum _Storage {
        case image(Image)
        case texture(Texture2D)
    }

    public typealias Body = Never

    let storage: _Storage
    var isResizable: Bool = false
    var renderMode: ImageRenderMode = .original

    public init(_ image: Image) {
        self.storage = .image(image)
    }

    public init(_ path: String, bundle: Bundle) {
        self.storage = .image(try! ResourceManager.loadSync(path, from: bundle))
    }

    public init(_ texture: Texture2D) {
        self.storage = .texture(texture)
    }

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        ImageViewNode(
            storage: self.storage,
            isResizable: self.isResizable,
            renderMode: self.renderMode,
            tintColor: inputs.environment.foregroundColor,
            content: self
        )
    }
}

public extension ImageView {
    func resizable() -> ImageView {
        var newValue = self
        newValue.isResizable = true
        return newValue
    }

    func renderMode(_ mode: ImageRenderMode) -> ImageView {
        var newValue = self
        newValue.renderMode = mode
        return newValue
    }
}

class ImageViewNode: ViewNode {

    let texture: Texture2D
    let isResizable: Bool
    let renderMode: ImageRenderMode
    let tintColor: Color?

    init<Content: View>(
        storage: ImageView._Storage,
        isResizable: Bool,
        renderMode: ImageRenderMode,
        tintColor: Color?,
        content: Content
    ) {
        switch storage {
        case .image(let image):
            self.texture = Texture2D(image: image)
        case .texture(let texture2D):
            self.texture = texture2D
        }

        self.tintColor = tintColor
        self.renderMode = renderMode
        self.isResizable = isResizable
        super.init(content: content)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if isResizable {
            return proposal.replacingUnspecifiedDimensions(by: Size(width: Float(texture.width), height: Float(texture.height)))
        }

        return proposal.replacingUnspecifiedDimensions()
    }

    override func draw(with context: inout GUIRenderContext) {
        context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)

        let tintColor = renderMode == .original ? .white : tintColor ?? .white
        context.drawRect(self.frame, texture: self.texture, color: tintColor)

        context.translateBy(x: -self.frame.origin.x, y: self.frame.origin.y)
    }
}

