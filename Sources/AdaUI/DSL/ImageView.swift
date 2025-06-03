//
//  ImageView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaAssets
import AdaRender
import AdaUtils
import Foundation
import Math

/// A view that displays an image.
public struct ImageView: View, ViewNodeBuilder {

    /// The storage type.
    public enum _Storage {
        /// The image.
        case image(Image)
        /// The texture.
        case texture(Texture2D)
    }

    public typealias Body = Never
    public var body: Never { fatalError() }

    let storage: _Storage
    var isResizable: Bool = false
    var renderMode: ImageRenderMode = .original

    /// Initialize a new image view.
    ///
    /// - Parameter image: The image.
    public init(_ image: Image) {
        self.storage = .image(image)
    }

    /// Initialize a new image view.
    ///
    /// - Parameter path: The path to the image.
    /// - Parameter bundle: The bundle.
    public init(_ path: String, bundle: Bundle) {
        self.storage = .texture(try! AssetsManager.loadSync(
            Texture2D.self, 
            at: path, 
            from: bundle
        ).asset)
    }

    /// Initialize a new image view.
    ///
    /// - Parameter texture: The texture.
    public init(_ texture: Texture2D) {
        self.storage = .texture(texture)
    }

    /// Build a view node.
    ///
    /// - Parameter context: The build context.
    /// - Returns: The view node.
    func buildViewNode(in context: BuildContext) -> ViewNode {
        ImageViewNode(
            storage: self.storage,
            isResizable: self.isResizable,
            renderMode: self.renderMode,
            tintColor: context.environment.foregroundColor,
            content: self
        )
    }
}

public extension ImageView {

    /// Make the image view resizable.
    ///
    /// - Returns: The image view.
    func resizable() -> ImageView {
        var newValue = self
        newValue.isResizable = true
        return newValue
    }

    /// Set the render mode.
    ///
    /// - Parameter mode: The render mode.
    /// - Returns: The image view.
    func renderMode(_ mode: ImageRenderMode) -> ImageView {
        var newValue = self
        newValue.renderMode = mode
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

    override func draw(with context: UIGraphicsContext) {
        let tintColor = renderMode == .original ? .white : tintColor ?? .white
        context.drawRect(self.frame, texture: self.texture, color: tintColor)
        super.draw(with: context)
    }
}
