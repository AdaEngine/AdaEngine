@_spi(AdaEngine) import AdaEngine

struct EditorParticleCurveEditor: View {
    let title: String
    let path: WritableKeyPath<ParticleEmitterDescriptor, ParticleCurve>
    let model: EditorParticleEffectEditorModel
    @State private var selectedKey: Int?
    @State private var dragLocation: Point?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .bold))
                Spacer()
                Button("+ Key") { model.addCurveKey(path) }.buttonStyle(DefaultButtonStyle())
                Button("− Key") {
                    if let selectedKey, model.emitter[keyPath: path].keys.indices.contains(selectedKey) {
                        model.updateEmitter { $0[keyPath: path].keys.remove(at: selectedKey) }
                    }
                    selectedKey = nil
                }
                .buttonStyle(DefaultButtonStyle())
                .disabled(selectedKey == nil || model.emitter[keyPath: path].keys.count <= 1)
            }
            GeometryReader { geometry in
                Canvas { context, size in
                    context.drawRect(Rect(origin: .zero, size: size), color: theme.editorColors.surfaceElevated)
                    let keys = model.emitter[keyPath: path].keys
                    let maximum = max(1, keys.map(\.value).max() ?? 1)
                    let points = keys.enumerated().map { index, key in
                        if index == selectedKey, let dragLocation { return dragLocation }
                        return Point(key.time * size.width, (1 - key.value / maximum) * size.height)
                    }
                    for index in 1..<points.count {
                        // Lines use render-space Y; rectangles convert from UI coordinates themselves.
                        context.drawLine(
                            start: [points[index - 1].x, -points[index - 1].y],
                            end: [points[index].x, -points[index].y],
                            lineWidth: 2, color: theme.editorColors.blue
                        )
                    }
                    for point in points {
                        context.drawRect(Rect(x: point.x - 3, y: point.y - 3, width: 6, height: 6), color: .white)
                    }
                }
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let keys = model.emitter[keyPath: path].keys
                    let maximum = max(1, keys.map(\.value).max() ?? 1)
                    let frame = geometry.frame(in: .global)
                    let origin = Point(frame.minX, frame.minY)
                    let start = value.startLocation - origin
                    let location = value.location - origin
                    if dragLocation == nil {
                        selectedKey = keys.indices.min {
                            distance(keys[$0], to: start, size: geometry.size, maximum: maximum)
                                < distance(keys[$1], to: start, size: geometry.size, maximum: maximum)
                        }
                    }
                    dragLocation = Point(min(geometry.size.width, max(0, location.x)), min(geometry.size.height, max(0, location.y)))
                }.onEnded { _ in
                    if let selectedKey, let dragLocation, geometry.size.width > 0, geometry.size.height > 0 {
                        let maximum = max(1, model.emitter[keyPath: path].keys.map(\.value).max() ?? 1)
                        model.moveCurveKey(path, index: selectedKey, time: dragLocation.x / geometry.size.width, value: (1 - dragLocation.y / geometry.size.height) * maximum)
                    }
                    dragLocation = nil
                })
            }.frame(height: 85)
            Text("Birth → Lifetime → End · Drag a key to edit").font(.system(size: 9)).foregroundColor(theme.editorColors.muted)
        }
        .accessibilityIdentifier("AdaEditor.ParticleFX.Curve.\(title)")
        .onChange(of: model.selectedEmitter) { _, _ in selectedKey = nil; dragLocation = nil }
    }

    private func distance(_ key: ParticleCurve.Key, to point: Point, size: Size, maximum: Float) -> Float {
        let delta = Point(key.time * size.width, (1 - key.value / maximum) * size.height) - point
        return delta.x * delta.x + delta.y * delta.y
    }
}
