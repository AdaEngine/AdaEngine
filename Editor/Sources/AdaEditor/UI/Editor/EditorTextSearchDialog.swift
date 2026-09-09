@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorTextSearchDialog: View {
    static let fieldIdentifier = "AdaEditor.TextSearch.Query"
    let viewModel: EditorViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var model: EditorTextSearchModel { viewModel.textSearch }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.54)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { close() }
                VStack(alignment: .leading, spacing: 0) {
                    header
                    searchField
                    results
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    preview
                    footer
                }
                .frame(width: max(0, min(1040, geometry.size.width - 40)), height: max(0, min(620, geometry.size.height - 40)))
                .background(RoundedRectangleShape(cornerRadius: 12).fill(theme.editorColors.surfaceElevated))
                .overlay { RoundedRectangleShape(cornerRadius: 12).stroke(theme.editorColors.border, lineWidth: 1) }
                .accessibilityIdentifier("AdaEditor.TextSearch.Dialog")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .keyboardShortcuts([
            KeyboardShortcutAction(.escape) { close() },
            KeyboardShortcutAction(.arrowDown) { model.moveSelection(by: 1) },
            KeyboardShortcutAction(.arrowUp) { model.moveSelection(by: -1) }
        ])
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                _ = EditorSearchShortcutMonitor.shared.focusSearchField(identifier: Self.fieldIdentifier)
            }
        }
        .onDisappear { model.close() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Find in Files").font(.system(size: 18, weight: .semibold))
            Text(model.status).font(.system(size: 12)).foregroundColor(theme.editorColors.muted)
                .accessibilityIdentifier("AdaEditor.TextSearch.Status")
            Spacer()
            Button("Close") { close() }
                .accessibilityIdentifier("AdaEditor.TextSearch.Close")
        }
        .foregroundColor(theme.editorColors.text)
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            TextField("Search text in project", text: Binding(
                get: { model.query },
                set: { model.query = $0; viewModel.refreshTextSearch() }
            ), onSubmit: { openSelected() })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
                .foregroundColor(theme.editorColors.text)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(Self.fieldIdentifier)
            Button("Aa") {
                model.caseSensitive.toggle()
                viewModel.refreshTextSearch()
            }
            .foregroundColor(model.caseSensitive ? theme.editorColors.blue : theme.editorColors.muted)
            .accessibilityIdentifier("AdaEditor.TextSearch.CaseSensitive")
            Button("Whole word") {
                model.wholeWord.toggle()
                viewModel.refreshTextSearch()
            }
            .foregroundColor(model.wholeWord ? theme.editorColors.blue : theme.editorColors.muted)
            .accessibilityIdentifier("AdaEditor.TextSearch.WholeWord")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(theme.editorColors.background)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.results.matches) { match in
                        Button {
                            model.selectedID = match.id
                        } label: {
                            HStack(spacing: 12) {
                                Text(match.lineText.trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.editorColors.text)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(match.relativePath):\(match.range.start.line + 1)")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.editorColors.muted)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(model.selectedID == match.id ? theme.editorColors.blue.opacity(0.26) : Color.clear)
                        }
                        .buttonStyle(DefaultButtonStyle())
                        .id(match.id)
                        .accessibilityIdentifier("AdaEditor.TextSearch.Result.\(match.id)")
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let match = model.selectedMatch {
                Text("\(match.relativePath) · line \(match.range.start.line + 1)")
                    .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                ScrollView(.horizontal) {
                    highlightedLine(match)
                }
                .frame(height: 42)
            } else {
                Text(model.status).font(.system(size: 12)).foregroundColor(theme.editorColors.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 94)
        .background(theme.editorColors.background)
        .accessibilityIdentifier("AdaEditor.TextSearch.Preview")
    }

    private func highlightedLine(_ match: EditorTextSearchMatch) -> some View {
        let line = match.lineText as NSString
        let start = match.range.start.character
        let end = match.range.end.character
        return HStack(spacing: 0) {
            Text(line.substring(to: start))
            Text(line.substring(with: NSRange(location: start, length: end - start)))
                .background(theme.editorColors.blue.opacity(0.4))
            Text(line.substring(from: end))
        }
        .font(.system(size: 13))
        .foregroundColor(theme.editorColors.text)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("↑↓ Select · Return Open · Esc Close")
                .font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
            if model.results.skippedFiles > 0 {
                Text("\(model.results.skippedFiles) binary, large or unreadable files skipped")
                    .font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
            }
            Spacer()
            Button("Open in Editor") { openSelected() }
                .disabled(model.selectedMatch == nil)
                .accessibilityIdentifier("AdaEditor.TextSearch.Open")
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
    }

    private func close() {
        model.close()
        dismiss()
    }

    private func openSelected() {
        guard let match = model.selectedMatch else { return }
        viewModel.openTextSearchMatch(match)
        dismiss()
    }
}

struct EditorTextSearchPresentation: ViewModifier {
    let viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.textSearch.isPresented },
                set: { if !$0 { viewModel.textSearch.close() } }
            )) {
                EditorTextSearchDialog(viewModel: viewModel)
            }
            .keyboardShortcuts([
                KeyboardShortcutAction(.f, modifiers: [.command, .shift]) {
                    viewModel.presentTextSearch()
                }
            ])
    }
}
