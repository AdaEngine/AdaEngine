#if os(iOS)
@_spi(AdaEngine) import AdaEngine

extension View {
    /// Keeps modal controls within the physical safe area while covering the entire workspace.
    func mobileEditorSafeAreaContent(_ edges: Edge.Set = [.horizontal, .bottom]) -> some View {
        MobileEditorSafeAreaContent(content: self, edges: edges)
    }
}

private struct MobileEditorSafeAreaContent<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.displaySafeAreaInsets) private var displaySafeAreaInsets
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.keyboardSafeAreaInset) private var keyboardSafeAreaInset
    let content: Content
    let edges: Edge.Set

    var body: some View {
        content
            .padding(EdgeInsets(
                top: 0,
                leading: edges.contains(.leading) ? max(0, displaySafeAreaInsets.leading - safeAreaInsets.leading) : 0,
                bottom: edges.contains(.bottom) ? displaySafeAreaInsets.bottom + keyboardSafeAreaInset : 0,
                trailing: edges.contains(.trailing) ? max(0, displaySafeAreaInsets.trailing - safeAreaInsets.trailing) : 0
            ))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(theme.editorColors.background.ignoresSafeArea())
    }
}
#endif
