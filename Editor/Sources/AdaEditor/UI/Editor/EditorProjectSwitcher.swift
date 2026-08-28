@_spi(AdaEngine) import AdaEngine
import Foundation

@Observable
@MainActor
final class EditorProjectSwitcherViewModel {
    let currentProject: EditorProjectReference?
    var isPresented = false
    var recentProjects: [EditorProjectReference] = []
    var searchText = ""
    var errorMessage: String?

    var searchTextBinding: Binding<String> {
        Binding(get: { self.searchText }, set: { self.searchText = $0 })
    }

    var filteredRecentProjects: [EditorProjectReference] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return recentProjects.filter { project in
            !isCurrentProject(project)
                && (query.isEmpty
                    || project.name.localizedCaseInsensitiveContains(query)
                    || project.path.localizedCaseInsensitiveContains(query))
        }
    }

    private let store: EditorProjectStore

    init(currentProject: EditorProjectReference?, store: EditorProjectStore = EditorProjectStore()) {
        self.currentProject = currentProject
        self.store = store
    }

    func toggle() {
        if isPresented {
            dismiss()
            return
        }

        searchText = ""
        errorMessage = nil
        reloadRecentProjects()
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        searchText = ""
        errorMessage = nil
    }

    func isCurrentProject(_ project: EditorProjectReference) -> Bool {
        guard let currentProject else {
            return false
        }
        return currentProject.path == project.path
    }

    func projectForOpening(_ project: EditorProjectReference) -> EditorProjectReference? {
        guard !isCurrentProject(project) else {
            dismiss()
            return nil
        }
        return projectForOpening(at: URL(fileURLWithPath: project.path, isDirectory: true))
    }

    func projectForOpening(at url: URL) -> EditorProjectReference? {
        do {
            let project = try store.openProject(at: url)
            dismiss()
            return project
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func reloadRecentProjects() {
        do {
            recentProjects = try store.loadProjects()
        } catch {
            recentProjects = []
            errorMessage = error.localizedDescription
        }
    }
}

struct EditorProjectSwitcherPanel: View {
    static let accessibilityIdentifier = "AdaEditor.ProjectSwitcher.Panel"
    static let searchAccessibilityIdentifier = "AdaEditor.ProjectSwitcher.Search"

    let viewModel: EditorProjectSwitcherViewModel
    let onOpenProject: (EditorProjectReference) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            Divider()

            if let currentProject = viewModel.currentProject {
                sectionTitle("This Window")
                projectRow(currentProject, isCurrent: true)
                Divider()
            }

            sectionTitle("Recent Projects")
            recentProjects

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Divider()

            Button(action: openLocalProject) {
                HStack(spacing: 8) {
                    Text("\u{E2C7}")
                        .font(AdaEditorMaterialSymbolFont.font(size: 16))
                    Text("Open Local Project…")
                        .font(.system(size: 12))
                    Spacer()
                }
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 12)
                .frame(height: 36)
            }
            .buttonStyle(DefaultButtonStyle())
            .accessibilityIdentifier("AdaEditor.ProjectSwitcher.OpenLocalProject")
        }
        .frame(width: EditorProjectSwitcherLayout.width, height: EditorProjectSwitcherLayout.height, alignment: .topLeading)
        .background(
            RoundedRectangleShape(cornerRadius: 10)
                .fill(theme.editorColors.surfaceElevated)
        )
        .overlay {
            RoundedRectangleShape(cornerRadius: 10)
                .stroke(theme.editorColors.border, lineWidth: 1)
        }
        .accessibilityIdentifier(Self.accessibilityIdentifier)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Text("\u{E8B6}")
                .font(AdaEditorMaterialSymbolFont.font(size: 16))
                .foregroundColor(theme.editorColors.muted)
            TextField("Search projects…", text: viewModel.searchTextBinding)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityIdentifier(Self.searchAccessibilityIdentifier)
        }
        .padding(.horizontal, 12)
        .frame(height: EditorProjectSwitcherLayout.searchHeight)
    }

    private var recentProjects: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.filteredRecentProjects) { project in
                    projectRow(project, isCurrent: false)
                }

                if viewModel.filteredRecentProjects.isEmpty {
                    Text(viewModel.searchText.isEmpty ? "No other recent projects" : "No matching projects")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(width: EditorProjectSwitcherLayout.width, height: EditorProjectSwitcherLayout.recentProjectsHeight)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.muted)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    private func projectRow(_ project: EditorProjectReference, isCurrent: Bool) -> some View {
        Button {
            guard let project = viewModel.projectForOpening(project) else {
                return
            }
            onOpenProject(project)
        } label: {
            HStack(spacing: 8) {
                Text("\u{E2C7}")
                    .font(AdaEditorMaterialSymbolFont.font(size: 16))
                    .foregroundColor(isCurrent ? theme.editorColors.blue : theme.editorColors.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 12))
                        .foregroundColor(theme.editorColors.text)
                        .lineLimit(1)
                    Text(ProjectOpeningViewModel.abbreviatedPath(project.path))
                        .font(.system(size: 9))
                        .foregroundColor(theme.editorColors.muted)
                        .lineLimit(1)
                }
                Spacer()
                if isCurrent {
                    Text("\u{E5CA}")
                        .font(AdaEditorMaterialSymbolFont.font(size: 16))
                        .foregroundColor(theme.editorColors.blue)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: EditorProjectSwitcherLayout.rowWidth, height: EditorProjectSwitcherLayout.rowHeight, alignment: .leading)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(isCurrent ? theme.editorColors.surface.opacity(0.72) : .clear)
            )
        }
        .buttonStyle(DefaultButtonStyle())
        .padding(.horizontal, 6)
        .accessibilityIdentifier("AdaEditor.ProjectSwitcher.Project.\(project.id)")
    }

    private func openLocalProject() {
        guard let url = ProjectOpenPicker.pickProjectURL(),
              let project = viewModel.projectForOpening(at: url) else {
            return
        }
        onOpenProject(project)
    }
}

enum EditorProjectSwitcherLayout {
    static let width: Float = 360
    static let height: Float = 422
    static let searchHeight: Float = 42
    static let recentProjectsHeight: Float = 238
    static let rowHeight: Float = 48
    static let rowWidth: Float = width - 12
    static let leadingOffset: Float = 32

    static func topOffset(toolbarHeight: Float) -> Float {
        toolbarHeight - 2
    }
}
