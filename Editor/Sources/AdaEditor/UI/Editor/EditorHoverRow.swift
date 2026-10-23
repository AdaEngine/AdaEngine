@_spi(AdaEngine) import AdaEngine

/// Keeps hover updates and cached drawing within one mounted list row.
struct EditorHoverRow<Content: View>: View {
    let content: (Bool) -> Content

    @State private var isHovered = false

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(isHovered)
            .drawingGroup()
            .onHover { hovering in
                if isHovered != hovering { isHovered = hovering }
            }
    }
}
