@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

@Observable
@MainActor
final class EditorExamplesViewModel {
    var items: [EditorExampleCatalog.Item] = []
    var selected: EditorExampleCatalog.Item?
    var loading = false
    var downloading = false
    var message: String?
    var query = ""
    private let service: EditorExampleService

    init(service: EditorExampleService = .configured()) { self.service = service }

    var results: [EditorExampleCatalog.Item] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? items : items.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func refresh() async {
        guard !loading, !downloading else {
            return
        }
        loading = true
        defer { loading = false }
        do {
            items = try await service.load().items
            selected = selected.flatMap { old in items.first { $0.id == old.id } } ?? items.first
            message = nil
        } catch { message = error.localizedDescription }
    }

    func download(to parent: URL, open: @MainActor (URL) -> Void) async {
        guard let selected, !downloading, !loading else {
            return
        }
        downloading = true
        message = "Downloading \(selected.title)…"
        defer { downloading = false }
        do {
            let destination = try await service.download(selected, to: parent)
            message = "Downloaded \(selected.title)."
            open(destination)
        } catch { message = error.localizedDescription }
    }
}

struct EditorExamplesDetail: View {
    let model: EditorExamplesViewModel
    let supportsSwiftProjects: Bool
    let openProject: @MainActor (URL) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                Text("EXAMPLES & SAMPLE GAMES")
                    .font(.system(size: 11))
                    .foregroundColor(AdaColorPalette.accentViolet)
                if let item = model.selected {
                    Text(item.title)
                        .font(AdaEditorTitleFont.font(size: 32))
                    Text(item.description)
                        .font(.system(size: 15))
                        .foregroundColor(AdaColorPalette.muted)
                    Text(item.tags.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundColor(AdaColorPalette.accentOrange)
                    Text("Download an editable copy into a folder of your choice and open it in Ada Studio.")
                        .font(.system(size: 13))
                        .foregroundColor(AdaColorPalette.muted)
                    if item.requiresSwift && !supportsSwiftProjects {
                        Text("This example contains Swift code and requires Ada Studio standalone.")
                            .font(.system(size: 13))
                            .foregroundColor(AdaColorPalette.accentOrange)
                    }
                    if item.tags.contains("visionOS") {
                        Text("Requires visionOS 26 and Xcode. Follow the project's README to run the immersive host.")
                            .font(.system(size: 13))
                            .foregroundColor(AdaColorPalette.muted)
                    }
                    Button(model.downloading ? "Downloading…" : "Download example") { chooseDestination() }
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(RoundedRectangleShape(cornerRadius: 10).fill(AdaColorPalette.accentViolet))
                        .disabled(model.downloading || model.loading || (item.requiresSwift && !supportsSwiftProjects))
                        .accessibilityIdentifier("AdaEditor.Launcher.DownloadExample")
                } else {
                    Text(model.loading ? "Loading examples…" : "Browse official AdaEngine examples and sample games.")
                        .font(.system(size: 15))
                }
                if let message = model.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(AdaColorPalette.accentOrange)
                        .accessibilityIdentifier("AdaEditor.Launcher.ExampleStatus")
                }
                Button("Refresh catalog") { Task { await model.refresh() } }
                    .foregroundColor(AdaColorPalette.accentViolet)
                    .disabled(model.loading || model.downloading)
                    .accessibilityIdentifier("AdaEditor.Launcher.RefreshExamples")
            }
            .foregroundColor(.white)
            .padding(32)
            .padding(.top, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("AdaEditor.Launcher.ExamplesDetail")
    }

    private func chooseDestination() {
        ProjectOpenPicker.presentProjectLocationPicker { result in
            switch result {
            case let .selected(parent):
                Task { await model.download(to: parent, open: openProject) }
            case .cancelled:
                break
            case let .unavailable(message):
                model.message = message
            }
        }
    }
}
