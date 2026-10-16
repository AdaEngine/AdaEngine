@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Observation

@MainActor
@Observable
final class EditorViewportPresentation {
    @ObservationIgnored var revision: UInt = 0
    private(set) var rulerRevision: UInt = 0
    private(set) var statusSuffix: String?
    private(set) var compassOrientation: CompassOrientation?

    struct CompassOrientation: Equatable {
        let right: Vector3
        let up: Vector3
        let front: Vector3
    }
    @ObservationIgnored private var rulerState: RulerState?
    @ObservationIgnored private var preparedAnnotations: Annotations?
    @ObservationIgnored private(set) var presentedAnnotations: Annotations?
    @ObservationIgnored private var annotationGeneration: UInt64 = 0
    @ObservationIgnored var annotationTheme = Theme()

    struct Annotations {
        let generation: UInt64
        let revision: UInt
        let size: Size
        let theme: Theme
        let grid: UIGraphicsContext
        let gizmos: UIGraphicsContext
        let interactionGizmo: EditorSceneViewportModel.PresentedGizmo
        let compassOrientation: CompassOrientation?
    }

    private struct RulerState: Equatable {
        let center: Vector2
        let zoom: Float
        let blend: Float
        let size: Size
    }

    func refresh(viewportModel: EditorSceneViewportModel) {
        revision &+= 1
        let suffix = viewportModel.statusSuffix
        if statusSuffix != suffix { statusSuffix = suffix }
        let state = viewportModel.smoothPerspectiveBlend < 1
            ? RulerState(center: viewportModel.twoDCenter, zoom: viewportModel.twoDZoom,
                         blend: viewportModel.smoothPerspectiveBlend, size: viewportModel.viewportSize)
            : nil
        if rulerState != state {
            rulerState = state
            rulerRevision &+= 1
        }
    }

    func invalidateAnnotations() {
        preparedAnnotations = nil
    }

    func prepareFrame(viewportModel: EditorSceneViewportModel, theme: Theme) -> @MainActor () -> Void {
        // SceneView debounces render-target resizing. Capture in the target's
        // logical size and stretch with that texture until the new target arrives.
        let cameraSize = viewportModel.cameraEntity()?.components[Camera.self]?.logicalViewport.rect.size
        let size = cameraSize.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil } ?? viewportModel.viewportSize
        let annotations: Annotations
        if let preparedAnnotations, preparedAnnotations.revision == revision,
            preparedAnnotations.size == size, preparedAnnotations.theme == theme {
            annotations = preparedAnnotations
        } else {
            var grid = UIGraphicsContext()
            var gizmos = UIGraphicsContext()
            viewportModel.drawGrid(in: &grid, size: size, theme: theme)
            let gizmo = viewportModel.drawGizmos(in: &gizmos, size: size, theme: theme)
            grid.commitDraw()
            gizmos.commitDraw()
            annotationGeneration &+= 1
            let orientation = viewportModel.displayMode == .threeD
                ? CompassOrientation(right: viewportModel.right3D, up: viewportModel.up3D, front: viewportModel.front3D) : nil
            annotations = Annotations(
                generation: annotationGeneration, revision: revision, size: size, theme: theme, grid: grid, gizmos: gizmos,
                interactionGizmo: viewportModel.captureGizmo(gizmo), compassOrientation: orientation
            )
            preparedAnnotations = annotations
        }
        return { [weak self, weak viewportModel] in
            guard let self else { return }
            self.presentedAnnotations = annotations
            viewportModel?.presentedGizmo = annotations.interactionGizmo
            if self.compassOrientation != annotations.compassOrientation {
                self.compassOrientation = annotations.compassOrientation
            }
        }
    }
}

/// Scene textures change each frame; editor annotations change only with the viewport.
struct EditorViewportDrawingLayer: View {
    enum Kind { case grid, gizmos }

    let viewportModel: EditorSceneViewportModel
    let presentation: EditorViewportPresentation
    let kind: Kind
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas(drawingRevision: { presentation.presentedAnnotations?.generation ?? (UInt64.max - UInt64(presentation.revision)) }) { context, size in
            if let annotations = presentation.presentedAnnotations {
                let source = kind == .grid ? annotations.grid : annotations.gizmos
                let scale = Vector3(size.width / max(1, annotations.size.width), size.height / max(1, annotations.size.height), 1)
                context.drawContents(of: source, transform: context.transform * Transform3D(scale: scale))
                return
            }
            switch kind {
            case .grid: viewportModel.drawGrid(in: &context, size: size, theme: theme)
            case .gizmos: viewportModel.drawGizmos(in: &context, size: size, theme: theme)
            }
        }
    }
}

extension EditorSceneViewportView {
    var viewportCoordinateRulerLayer: some View {
        EditorViewportRulerLayer(viewportModel: viewportModel, presentation: viewportPresentation)
    }
}

struct EditorViewportRulerLayer: View {
    let viewportModel: EditorSceneViewportModel
    let presentation: EditorViewportPresentation
    @Environment(\.theme) private var theme

    var body: some View {
        let revision = presentation.rulerRevision
        return GeometryReader { proxy in
            // A declaration is required inside AdaUI's result builder.
            // swiftlint:disable:next redundant_discardable_let
            let _ = revision
            let ruler = viewportModel.coordinateRuler(in: proxy.size)
            ZStack(anchor: .topLeading) {
                RectangleShape()
                    .fill(theme.editorColors.surface.opacity(0.92 * ruler.opacity))
                    .frame(width: proxy.size.width, height: 20)
                RectangleShape()
                    .fill(theme.editorColors.surface.opacity(0.92 * ruler.opacity))
                    .frame(width: 40, height: proxy.size.height)
                ForEach(ruler.labels, id: \.id) { label in
                    coordinateRulerLabel(label, opacity: ruler.opacity)
                }
                Text("X")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.78, green: 0.24, blue: 0.28).opacity(ruler.opacity))
                    .frame(width: 16, height: 18)
                    .offset(x: max(40, proxy.size.width - 18), y: 1)
                Text("Y")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.24, green: 0.60, blue: 0.31).opacity(ruler.opacity))
                    .frame(width: 16, height: 18)
                    .offset(x: 2, y: max(20, proxy.size.height - 20))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    @ViewBuilder
    func coordinateRulerLabel(
        _ label: EditorSceneViewportCoordinateRuler.Label,
        opacity: Float
    ) -> some View {
        switch label.axis {
        case .x:
            Text(label.text)
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted.opacity(opacity))
                .frame(width: 48, height: 18)
                .offset(x: label.position.x - 24, y: 1)
        case .y:
            Text(label.text)
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted.opacity(opacity))
                .frame(width: 34, height: 18, alignment: .trailing)
                .offset(x: 2, y: label.position.y - 9)
        }
    }
}

struct EditorViewportStatusLabel: View {
    let presentation: EditorViewportPresentation
    let viewportModel: EditorSceneViewportModel
    let warning: String?
    let entityCount: Int

    var body: some View {
        Text(warning.map { "Scene warning: \($0)" }
            ?? "Loaded \(entityCount) entities · \(presentation.statusSuffix ?? viewportModel.statusSuffix)")
            .accessibilityIdentifier("AdaEditor.SceneViewport.Status")
    }
}
