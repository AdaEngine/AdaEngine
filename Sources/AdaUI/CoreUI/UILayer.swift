//
//  UILayotu.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.07.2024.
//

import AdaUtils
import AdaRender
import Math

@MainActor
class UILayer {
    
    private var texture: RenderTexture?
    private(set) var frame: Rect
    private let drawBlock: (inout UIGraphicsContext, Size) -> Void
    var debugLabel: String?

    weak var parent: UILayer?

    init(frame: Rect, drawBlock: @escaping (inout UIGraphicsContext, Size) -> Void) {
        self.frame = frame
        self.drawBlock = drawBlock
    }

    func setFrame(_ frame: Rect) {
        if frame == .zero {
            return
        }

        self.frame = frame
        self.invalidate()
    }

    func invalidate() {
        self.texture = nil
        self.parent?.invalidate()
    }

    final func drawLayer(in context: UIGraphicsContext) {
        guard frame.height > 0 && frame.width > 0 else {
            return
        }

        if let texture = texture {
            context.drawRect(Rect(origin: .zero, size: frame.size), texture: texture, color: .white)
        } else {
            self.texture = context.createLayer(from: self, drawBlock: { [weak self] context in
                guard let self = self else {
                    return
                }
                self.drawBlock(&context, self.frame.size)
            })
        }
    }
}

extension UIGraphicsContext {
    @MainActor
    func createLayer(from layer: UILayer, drawBlock: (inout UIGraphicsContext) -> Void) -> RenderTexture {
        let renderTexture = RenderTexture(
            size: SizeInt(width: Int(layer.frame.size.width) , height: Int(layer.frame.size.width)),
            scaleFactor: 1,
            format: .bgra8,
            debugLabel: layer.debugLabel.flatMap { "Layer \($0)" }
        )

//        var context = UIGraphicsContext(texture: renderTexture)
//        context.environment = self.environment
//        context.beginDraw(in: layer.frame.size, scaleFactor: 1)
//        drawBlock(&context)
//        context.commitDraw()

        return renderTexture
    }
}
