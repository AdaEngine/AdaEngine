@_spi(AdaEngine) import AdaEngine
import Observation

@MainActor
@Observable
final class EditorViewportPresentation {
    var revision: UInt = 0
}

/// Scene textures change each frame; editor annotations change only with the viewport.
struct EditorViewportDrawingLayer: View {
    enum Kind { case grid, gizmos }

    let viewportModel: EditorSceneViewportModel
    let presentation: EditorViewportPresentation
    let kind: Kind
    @Environment(\.theme) private var theme

    var body: some View {
        // Read outside Canvas so a navigation update invalidates the retained layer.
        // swiftlint:disable:next redundant_discardable_let
        let _ = presentation.revision
        Canvas { context, size in
            switch kind {
            case .grid: viewportModel.drawGrid(in: &context, size: size, theme: theme)
            case .gizmos: viewportModel.drawGizmos(in: &context, size: size, theme: theme)
            }
        }
        .drawingGroup()
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
        let revision = presentation.revision
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
        // Subscribe at the label, not at the viewport that owns SceneView.
        // swiftlint:disable:next redundant_discardable_let
        let _ = presentation.revision
        Text(warning.map { "Scene warning: \($0)" }
            ?? "Loaded \(entityCount) entities · \(viewportModel.statusSuffix)")
            .accessibilityIdentifier("AdaEditor.SceneViewport.Status")
    }
}
