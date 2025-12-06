//
//  ImageView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaAssets
@_spi(Internal) import AdaRender
import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Math

/// The render mode of the image view.
public enum ImageRenderMode: Codable, Sendable {
    /// The original render mode.
    case original
    /// The template render mode.
    case template
}

extension Image: View, ViewNodeBuilder {
    public typealias Body = Never
    public var body: Never { fatalError() }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        ImageViewNode(
            image: self,
            isResizable: self.options[Keys.resizable.rawValue] as! Bool,
            renderMode: self.options[Keys.renderMode.rawValue] as! ImageRenderMode,
            tintColor: context.environment.foregroundColor,
            content: self
        )
    }
}


public extension Image {

    private enum Keys: String {
        case resizable
        case renderMode
    }

    /// Make the image resizable.
    ///
    /// - Returns: The image view.
    func resizable() -> Image {
        var newValue = self
        newValue.options[Keys.resizable.rawValue] = true
        return newValue
    }

    /// Set the render mode.
    ///
    /// - Parameter mode: The render mode.
    /// - Returns: The image view.
    func renderMode(_ mode: ImageRenderMode) -> Image {
        var newValue = self
        newValue.options[Keys.renderMode.rawValue] = mode
        return newValue
    }
}


final class ImageViewNode: ViewNode {

    /// The texture.
    let texture: Texture2D
    /// A Boolean value indicating whether the image view is resizable.
    let isResizable: Bool
    /// The render mode.
    let renderMode: ImageRenderMode
    /// The tint color.
    let tintColor: Color?

    init<Content: View>(
        image: Image,
        isResizable: Bool,
        renderMode: ImageRenderMode,
        tintColor: Color?,
        content: Content
    ) {
        self.texture = Texture2D(image: image)
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

    override func draw(with context: UIGraphicsContext) {
        let tintColor = renderMode == .original ? .white : tintColor ?? .white
        context.drawRect(self.frame, texture: self.texture, color: tintColor)
        super.draw(with: context)
    }
}
