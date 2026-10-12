@_spi(AdaEngine) import AdaEngine
import AdaInput
@_spi(Internal) import AdaUI
import Math

struct EditorUISceneSurface: UIViewRepresentable {
    let preview: UIView
    let model: EditorUISceneModel
    var zoom: Float?
    var windowFrame: (() -> Rect)?
    var isCompact = false
    func makeUIView(in _: Context) -> EditorUISceneHost { EditorUISceneHost(frame: .zero) }
    func updateUIView(_ view: EditorUISceneHost, in _: Context) {
        view.model = model
        model.designerDrag.canvasFrame = windowFrame
        model.designerDrag.canvasZoom = zoom ?? model.zoom
        model.designerDrag.isCompact = isCompact
        model.designerDrag.onFeedbackChange = { [weak view] in view?.setNeedsDisplay() }
        view.host.configure(
            previewView: preview,
            zoom: zoom ?? model.zoom,
            isInteractive: model.isInteractive,
            contentSize: Size(width: model.width, height: model.height)
        )
        view.setNeedsDisplay()
    }
}

final class EditorUISceneHost: UIView {
    let host = EditorPreviewHostView()
    weak var model: EditorUISceneModel?

    required init(frame: Rect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(host)
    }
    override func layoutSubviews() {
        host.frame = bounds
        super.layoutSubviews()
    }
    override func hitTest(_ point: Point, with event: any InputEvent) -> UIView? {
        guard bounds.contains(point: point) else {
            return nil
        }
        return model?.isInteractive == true ? host.hitTest(point, with: event) : self
    }
    override func onMouseEvent(_ event: MouseEvent) {
        if model?.isInteractive == true { host.onMouseEvent(event); return }
        if event.phase == .began { model?.designerDrag.suppressesCanvasSelection = false }
        guard model?.designerDrag.suppressesCanvasSelection != true else { return }
        guard model?.isInteractive == false, event.phase == .ended else {
            return
        }
        select(at: host.previewPoint(from: event.mousePosition))
    }
    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if model?.isInteractive == true { host.onTouchesEvent(touches); return }
        if touches.contains(where: { $0.phase == .began }) { model?.designerDrag.suppressesCanvasSelection = false }
        guard model?.designerDrag.suppressesCanvasSelection != true else { return }
        if let touch = touches.first(where: { $0.phase == .ended }), model?.isInteractive == false {
            select(at: host.previewPoint(from: touch.location))
        }
    }
    override func draw(with context: UIGraphicsContext) {
        super.draw(with: context)
        guard let model, !model.isInteractive, let preview = host.previewView as? UIContainerView<UISceneView> else {
            return
        }
        func selectedFrames(_ node: UINodeSnapshot) -> [Rect] {
            (node.sceneNodeID == model.selectedID ? [node.absoluteFrame] : []) + node.children.flatMap(selectedFrames)
        }
        let zoom = host.zoom
        let origin = Point(x: frame.minX + (bounds.width - model.width * zoom) / 2, y: frame.minY + (bounds.height - model.height * zoom) / 2)
        if let feedback = model.designerDrag.feedback {
            let color: Color = feedback.valid ? .blue : .red
            func scaled(_ rect: Rect) -> Rect {
                Rect(x: origin.x + rect.minX * zoom, y: origin.y + rect.minY * zoom, width: rect.width * zoom, height: rect.height * zoom)
            }
            func outline(_ rect: Rect) {
                let rect = scaled(rect)
                context.drawRect(Rect(x: rect.minX, y: rect.minY, width: rect.width, height: 2), color: color)
                context.drawRect(Rect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2), color: color)
                context.drawRect(Rect(x: rect.minX, y: rect.minY, width: 2, height: rect.height), color: color)
                context.drawRect(Rect(x: rect.maxX - 2, y: rect.minY, width: 2, height: rect.height), color: color)
            }
            context.drawRect(scaled(feedback.target), color: color.opacity(0.08))
            outline(feedback.target)
            outline(feedback.ghost)
            if let insertion = feedback.insertion { context.drawRect(scaled(insertion), color: color) }
        }
        for source in preview.uiTreeRoots().flatMap(selectedFrames) {
            let rect = Rect(
                x: origin.x + source.minX * zoom,
                y: origin.y + source.minY * zoom,
                width: source.width * zoom,
                height: source.height * zoom
            )
            context.drawRect(Rect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), color: .blue)
            context.drawRect(Rect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1), color: .blue)
            context.drawRect(Rect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: .blue)
            context.drawRect(Rect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height), color: .blue)
        }
    }

    private func select(at point: Point) {
        guard let preview = host.previewView as? UIContainerView<UISceneView> else {
            return
        }
        let roots = preview.uiTreeRoots()
        func find(_ node: UINodeSnapshot) -> String? {
            for child in node.children.reversed() {
                if let match = find(child) {
                    return match
                }
            }
            guard node.absoluteFrame.contains(point: point), let id = node.sceneNodeID else {
                return nil
            }
            var belongs = false
            model?.document.root
                .visit {
                    if $0.id == id {
                        belongs = true
                    }
                }
            return belongs ? id : nil
        }
        if let selected = roots.compactMap(find).first {
            model?.selectedID = selected
        }
    }
}
