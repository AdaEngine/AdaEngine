//
//  UIImageView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 20.06.2024.
//

public enum ImageRenderMode {
    case original
    case template
}

public class UIImageView: UIView {

    public var image: Image? {
        get {
            self.texture?.image
        }
        set {
            self.setImage(newValue)
        }
    }

    public var texture: Texture2D? {
        didSet {
            parentView?.setNeedsLayout()
        }
    }

    public var tintColor: Color = .white

    private func setImage(_ image: Image?) {
        guard let image else {
            self.texture = nil
            return
        }

        self.texture = Texture2D(image: image)
    }

    public override func draw(in rect: Rect, with context: GUIRenderContext) {
        context.drawRect(rect, texture: self.texture, color: self.tintColor)
    }

    public override var minimumContentSize: Size {
        return Size(width: Float(self.texture?.width ?? 0), height: Float(self.texture?.height ?? 0))
    }

}
