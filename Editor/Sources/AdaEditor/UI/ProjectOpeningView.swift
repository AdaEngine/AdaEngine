//
//  ProjectOpeningView.swift
//  AdaEngine
//

// swiftlint:disable type_body_length
@_spi(AdaEngine) import AdaEngine

private typealias LauncherColor = AdaColorPalette
enum ProjectOpeningLayout {
    static let usesNavigationSplitView = false
    static let detailUsesNavigationStack = false
    static let detailUsesSearchable = false
    static let windowWidth: Float = 1024
    static let windowHeight: Float = 700
    static let sidebarWidth: Float = 68
    static let explorerWidth: Float = 320
    static let detailWidth: Float = windowWidth - sidebarWidth - explorerWidth
    static let detailPadding: Float = 32
    static let detailContentWidth: Float = detailWidth - detailPadding * 2
    static let previewHeight: Float = 200
    static let detailRowHeight: Float = 44
    static let detailsRowCount: Float = 5
    static let actionButtonHeight: Float = 42
    static let actionButtonSpacing: Float = 12
    static let detailActionButtonCount = 0
    static let searchUsesGradient = false
    static let searchCapsuleWidth: Float = explorerWidth - 32
    static let searchCapsuleHeight: Float = 38
    static let searchBottomPadding: Float = 12
    static let trafficLightOffsetY: Float = 0
    static let logoTopPadding: Float = 58
    static let explorerTopPadding: Float = 56
    static let landingTopPadding: Float = 62
    static let textFieldBackgroundAlpha: Float = 0.11
    static let textFieldFocusedBorderAlpha: Float = 0.24

    static var columnsWidth: Float {
        sidebarWidth + explorerWidth + detailWidth
    }

    static var fixedDetailContentHeight: Float {
        59 + 32 + previewHeight + 32 + detailRowHeight * detailsRowCount
    }
}

enum ProjectOpeningWindowConfiguration {
    static let isResizable = true
    static let hasShadow = true
}

enum ProjectOpeningAccessibility {
    static let sidebar = "AdaEditor.Launcher.Sidebar"
    static let explorer = "AdaEditor.Launcher.Explorer"
    static let detail = "AdaEditor.Launcher.Detail"
    static let search = "AdaEditor.Launcher.Search"
    static let createProject = "AdaEditor.Launcher.CreateProject"
    static let createHeader = "AdaEditor.Launcher.CreateHeader"
    static let createDescription = "AdaEditor.Launcher.CreateDescription"
    static let projectType = "AdaEditor.Launcher.ProjectType"
    static let createActions = "AdaEditor.Launcher.CreateActions"
}

enum ProjectOpeningLandingSpec {
    static let primaryButtonTitles = ["Create new project", "Open project"]
    static let footerButtonTitles = ["Report issues", "Support", "Github"]
    static let logoSize: Float = 128
    static let primaryButtonWidth: Float = 220
    static let primaryButtonHeight: Float = 48
    static let footerButtonHeight: Float = 34
}

struct ProjectOpeningView: View {
    let autoOpenLastProject: Bool
    let initiallyCreatingProject: Bool
    @State private var viewModel = ProjectOpeningViewModel()
    @State private var didAttemptAutoOpenLastProject = false
    private let logoImage = ProjectOpeningAssets.loadAdaEngineLogo()

    init(autoOpenLastProject: Bool = true, initiallyCreatingProject: Bool = false) {
        self.autoOpenLastProject = autoOpenLastProject
        self.initiallyCreatingProject = initiallyCreatingProject
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            projectExplorer
            projectDetail
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .foregroundColor(.white)
                .accessibilityIdentifier(ProjectOpeningAccessibility.detail)
        }
        .frame(
            minWidth: ProjectOpeningLayout.windowWidth,
            maxWidth: .infinity,
            minHeight: ProjectOpeningLayout.windowHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(LauncherColor.window)
        .menuBar(EditorMenuBar.makeMenus())
        .onChange(of: viewModel.projectToOpenInEditorToken) { _, _ in
            guard let project = viewModel.consumeProjectToOpenInEditor() else {
                return
            }
            ProjectEditorLauncher.openEditor(for: project)
        }
        .onAppear {
            EditorMenuCommandRouter.shared.install(owner: viewModel) { [weak viewModel] command in
                guard let viewModel else { return false }
                switch command {
                case .showSettings:
                    EditorSettingsWindowController.open(project: viewModel.selectedProject, selectedSection: .general)
                case .newProject:
                    viewModel.beginCreateNewProject()
                case .openProject:
                    ProjectOpenPicker.presentProjectPicker { url in
                        guard let url else { return }
                        viewModel.openProject(at: url)
                    }
                case .showProjectSettings:
                    EditorSettingsWindowController.open(project: viewModel.selectedProject, selectedSection: .project)
                default:
                    return false
                }
                return true
            }
            if initiallyCreatingProject {
                viewModel.beginCreateNewProject()
            }
            openLastProjectOnLaunchIfNeeded()
        }
        .onDisappear {
            EditorMenuCommandRouter.shared.uninstall(owner: viewModel)
        }
    }

    private func openLastProjectOnLaunchIfNeeded() {
        guard autoOpenLastProject, !didAttemptAutoOpenLastProject else {
            return
        }

        didAttemptAutoOpenLastProject = true
        Task { @MainActor in
            _ = await viewModel.openLastProjectIfAvailable()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .center, spacing: 6) {
            if let logoImage {
                logoImage
                    .resizable()
                    .frame(width: 38, height: 38)
                    .padding(.top, ProjectOpeningLayout.logoTopPadding)
                    .padding(.bottom, 4)
            } else {
                Text("A")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .padding(.top, ProjectOpeningLayout.logoTopPadding)
                    .padding(.bottom, 4)
            }

            launcherSectionButton(.projects)
            launcherSectionButton(.templates)
            launcherSectionButton(.samples)

            Spacer()
            Button {
                EditorSettingsWindowController.open(project: viewModel.selectedProject, selectedSection: .general)
            } label: {
                Text("⚙")
                    .font(.system(size: 20))
                    .foregroundColor(LauncherColor.muted)
                    .frame(width: 54, height: 36)
            }
            .buttonStyle(LauncherIconButtonStyle())
            .frame(width: 54, height: 36)
        }
        .frame(width: ProjectOpeningLayout.sidebarWidth)
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        .background(LauncherColor.sidebar)
        .accessibilityIdentifier(ProjectOpeningAccessibility.sidebar)
    }

    private var projectExplorer: some View {
        projectExplorerContent
            .frame(width: ProjectOpeningLayout.explorerWidth)
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .background(LauncherColor.explorer)
            .overlay {
                HStack(spacing: 0) {
                    Spacer()
                    LauncherColor.glassBorder.frame(width: 1)
                }
            }
            .accessibilityIdentifier(ProjectOpeningAccessibility.explorer)
    }

    private var projectExplorerContent: AnyView {
        switch viewModel.selectedSection {
        case .projects:
            AnyView(projectsExplorer)
        case .templates:
            AnyView(templatesExplorer)
        case .samples:
            AnyView(samplesExplorer)
        }
    }

    private var projectsExplorer: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchCapsule
                .padding(.leading, 16)
                .padding(.top, ProjectOpeningLayout.explorerTopPadding)
                .padding(.bottom, ProjectOpeningLayout.searchBottomPadding)

            launcherListHeader("Recent Projects")

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.filteredRecentProjects) { project in
                        projectRow(project)
                    }

                    if viewModel.filteredRecentProjects.isEmpty {
                        Text("No recent projects")
                            .font(.system(size: 13))
                            .foregroundColor(LauncherColor.muted)
                            .padding(.leading, 20)
                            .padding(.top, 14)
                    }
                }
            }
            .frame(width: ProjectOpeningLayout.explorerWidth)
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)

            launcherListHeader("Open")
            templateRow(
                title: "Open Existing Package",
                subtitle: viewModel.existingProjectPathDisplayText,
                badge: "SPM",
                isActive: false,
                action: openProjectPicker
            )
        }
    }

    private var templatesExplorer: some View {
        VStack(alignment: .leading, spacing: 0) {
            launcherListHeader("Project Templates")
                .padding(.top, ProjectOpeningLayout.explorerTopPadding)
            projectTemplateRow(.adaScript)
            projectTemplateRow(.adaScriptWithSwift)
            Spacer()
        }
    }

    private var samplesExplorer: some View {
        VStack(alignment: .leading, spacing: 0) {
            launcherListHeader("Starter Samples")
                .padding(.top, ProjectOpeningLayout.explorerTopPadding)
            templateRow(
                title: "AdaScript System",
                subtitle: "Per-frame system ready for gameplay code",
                badge: "ADA",
                isActive: false
            ) {
                viewModel.beginCreateNewProject(template: .adaScript, suggestedName: "ScriptSample")
            }
            templateRow(
                title: "Hybrid Window",
                subtitle: "AdaScript system with an editable Swift app",
                badge: "ADA+SWIFT",
                isActive: false
            ) {
                viewModel.beginCreateNewProject(template: .adaScriptWithSwift, suggestedName: "HybridSample")
            }
            Spacer()
        }
    }

    private func projectTemplateRow(_ template: EditorProjectTemplate) -> some View {
        templateRow(
            title: template.displayName,
            subtitle: template.summary,
            badge: template == .adaScript ? "ADA" : "ADA+SWIFT",
            isActive: viewModel.isCreatingNewProject && viewModel.selectedTemplate == template
        ) {
            viewModel.beginCreateNewProject(template: template)
        }
    }

    private func templateRow(
        title: String,
        subtitle: String,
        badge: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(badge)
                        .font(.system(size: 9))
                        .foregroundColor(LauncherColor.accentOrange)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(LauncherColor.muted)
                    .lineLimit(1)
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .frame(width: ProjectOpeningLayout.explorerWidth, height: 64, alignment: .leading)
        }
        .buttonStyle(LauncherPlainButtonStyle(active: isActive))
    }

    private var searchCapsule: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("⌕")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.72))
            TextField("Search projects...", text: viewModel.searchQueryBinding)
                .font(.system(size: 13))
                .foregroundColor(.white)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .frame(width: ProjectOpeningLayout.searchCapsuleWidth, height: ProjectOpeningLayout.searchCapsuleHeight)
        .background {
            CapsuleShape().fill(LauncherColor.searchCapsuleSurface)
        }
        .glassEffect(LauncherColor.searchCapsuleGlass, in: CapsuleShape())
        .overlay {
            CapsuleShape().stroke(LauncherColor.searchCapsuleBorder, lineWidth: 1)
        }
        .textFieldStyle(PlainTextFieldStyle())
        .accessibilityIdentifier(ProjectOpeningAccessibility.search)
    }

    private var projectDetail: some View {
        let project = viewModel.detailProject

        if viewModel.isCreatingNewProject {
            return AnyView(createProjectForm)
        }

        if project == nil {
            return AnyView(emptyProjectLanding)
        }

        return AnyView(VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE PROJECT")
                    .font(.system(size: 10))
                    .foregroundColor(LauncherColor.accentViolet)
                Text(project?.name ?? "Create or Open")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: ProjectOpeningLayout.detailContentWidth, height: 59, alignment: .topLeading)

            Spacer().frame(height: 32)

            ZStack {
                RoundedRectangleShape(cornerRadius: 12).fill(LauncherColor.preview)
                Text("NO RENDER PREVIEW AVAILABLE")
                    .font(.system(size: 11))
                    .foregroundColor(LauncherColor.muted.opacity(0.4))
            }
            .frame(height: ProjectOpeningLayout.previewHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangleShape(cornerRadius: 12).stroke(LauncherColor.glassBorder, lineWidth: 1)
            }

            Spacer().frame(height: 32)

            detailsList(project)

            Spacer().frame(height: 28)

            statusAndDiagnostics

            Spacer()
        }
        .padding(ProjectOpeningLayout.detailPadding)
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(LauncherColor.window))
    }

    private var createProjectForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CREATE NEW PROJECT")
                    .font(.system(size: 10))
                    .foregroundColor(LauncherColor.accentViolet)

                Text("New Ada Project")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: ProjectOpeningLayout.detailContentWidth, alignment: .leading)
            }
            .frame(width: ProjectOpeningLayout.detailContentWidth, height: 59, alignment: .topLeading)
            .accessibilityIdentifier(ProjectOpeningAccessibility.createHeader)

            Text("Choose a project name and a destination folder. AdaEditor will create a new folder with the project files inside it.")
                .font(.system(size: 13))
                .foregroundColor(LauncherColor.muted)
                .lineLimit(3)
                .frame(width: ProjectOpeningLayout.detailContentWidth, alignment: .leading)
                .padding(.top, 12)
                .accessibilityIdentifier(ProjectOpeningAccessibility.createDescription)

            VStack(alignment: .leading, spacing: 18) {
                createFormField(title: "Project Type") {
                    HStack(alignment: .center, spacing: 10) {
                        projectTypeButton(.adaScript)
                        projectTypeButton(.adaScriptWithSwift)
                    }
                }
                .accessibilityIdentifier(ProjectOpeningAccessibility.projectType)

                createFormField(title: "Project Name") {
                    TextField("AdaGame", text: viewModel.projectNameBinding)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangleShape(cornerRadius: 10).fill(LauncherColor.input))
                        .overlay {
                            RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.inputBorder, lineWidth: 1)
                        }
                        .textFieldStyle(PlainTextFieldStyle())
                }

                createFormField(title: "Location") {
                    HStack(alignment: .center, spacing: 10) {
                        Text(viewModel.projectLocationDisplayText)
                            .font(.system(size: 13))
                            .foregroundColor(viewModel.projectLocation.isEmpty ? LauncherColor.muted : .white)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            chooseProjectLocation()
                        } label: {
                            Text("Browse…")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(LauncherInlineButtonStyle())
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangleShape(cornerRadius: 10).fill(LauncherColor.input))
                    .overlay {
                        RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.inputBorder, lineWidth: 1)
                    }
                }
            }
            .padding(.top, 28)

            Spacer()

            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(LauncherColor.muted)
                .lineLimit(2)
                .frame(height: 34, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 12) {
                Button {
                    viewModel.isCreatingNewProject = false
                    viewModel.statusMessage = "Project creation cancelled."
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(LauncherActionButtonStyle(kind: .outline))

                Spacer()

                Button {
                    viewModel.createBlankTemplateProject()
                } label: {
                    Text("Create Project")
                }
                .buttonStyle(LauncherActionButtonStyle(kind: .primary))
                .disabled(!viewModel.canCreateProject)
                .opacity(viewModel.canCreateProject ? 1.0 : 0.45)
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(ProjectOpeningAccessibility.createActions)
        }
        .padding(ProjectOpeningLayout.detailPadding)
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(LauncherColor.window)
    }

    private var statusAndDiagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(viewModel.validationDiagnostics.isEmpty ? LauncherColor.muted : LauncherColor.accentOrange)
                .lineLimit(3)

            if !viewModel.validationDiagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PROJECT VALIDATION")
                        .font(.system(size: 10))
                        .foregroundColor(LauncherColor.accentOrange)
                    ForEach(viewModel.validationDiagnostics) { diagnostic in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.validationSummary ?? diagnostic.code)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            Text(diagnostic.message)
                                .font(.system(size: 11))
                                .foregroundColor(LauncherColor.muted)
                                .lineLimit(2)
                            Text(diagnostic.recoverySuggestion)
                                .font(.system(size: 11))
                                .foregroundColor(LauncherColor.accentOrange)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangleShape(cornerRadius: 10).fill(LauncherColor.input))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.accentOrange.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func createFormField<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(LauncherColor.muted)
            content()
        }
    }

    private func projectTypeButton(_ template: EditorProjectTemplate) -> some View {
        let isActive = viewModel.selectedTemplate == template
        return Button {
            viewModel.selectedTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Text(template == .adaScript ? "Script-first" : "Hybrid")
                    .font(.system(size: 10))
                    .foregroundColor(LauncherColor.muted)
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 10).fill(isActive ? LauncherColor.accentViolet.opacity(0.18) : LauncherColor.input))
            .overlay {
                RoundedRectangleShape(cornerRadius: 10).stroke(isActive ? LauncherColor.accentViolet : LauncherColor.inputBorder, lineWidth: 1)
            }
        }
        .buttonStyle(LauncherPlainButtonStyle(active: false))
    }

    private var emptyProjectLanding: some View {
        VStack(alignment: .center, spacing: 0) {
            if let logoImage {
                logoImage
                    .resizable()
                    .frame(width: ProjectOpeningLandingSpec.logoSize, height: ProjectOpeningLandingSpec.logoSize)
                    .padding(.bottom, 20)
            } else {
                Text("A")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .frame(width: ProjectOpeningLandingSpec.logoSize, height: ProjectOpeningLandingSpec.logoSize)
                    .background(RoundedRectangleShape(cornerRadius: 28).fill(LauncherColor.glassSurface))
                    .overlay {
                        RoundedRectangleShape(cornerRadius: 28).stroke(LauncherColor.glassBorder, lineWidth: 1)
                    }
                    .padding(.bottom, 20)
            }

            Text("AdaEngine")
                .font(.system(size: 26))
                .foregroundColor(.white)

            Text("Create a new game project or continue with an existing package.")
                .font(.system(size: 12))
                .foregroundColor(LauncherColor.muted)
                .padding(.top, 6)
                .padding(.bottom, 26)

            VStack(alignment: .center, spacing: 14) {
                Button {
                    viewModel.beginCreateNewProject()
                } label: {
                    Text(ProjectOpeningLandingSpec.primaryButtonTitles[0])
                }
                .accessibilityIdentifier(ProjectOpeningAccessibility.createProject)

                Button {
                    openProjectPicker()
                } label: {
                    Text(ProjectOpeningLandingSpec.primaryButtonTitles[1])
                }
            }
            .buttonStyle(LauncherGlassButtonStyle())

            Spacer()

            HStack(alignment: .center, spacing: 10) {
                Button {
                    viewModel.statusMessage = "Issue reporting will open from AdaEditor soon."
                } label: {
                    Text(ProjectOpeningLandingSpec.footerButtonTitles[0])
                }

                Button {
                    viewModel.statusMessage = "Support links will open from AdaEditor soon."
                } label: {
                    Text(ProjectOpeningLandingSpec.footerButtonTitles[1])
                }

                Button {
                    viewModel.statusMessage = "GitHub link will open from AdaEditor soon."
                } label: {
                    Text(ProjectOpeningLandingSpec.footerButtonTitles[2])
                }
            }
            .buttonStyle(LauncherGrayButtonStyle())
            .padding(.bottom, 24)
        }
        .padding(.top, ProjectOpeningLayout.landingTopPadding)
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity
        )
        .background(LauncherColor.window)
    }

    private func openProjectPicker() {
        ProjectOpenPicker.presentProjectPicker { projectURL in
            guard let projectURL else {
                viewModel.statusMessage = "Open project cancelled."
                return
            }
            viewModel.openProject(at: projectURL)
        }
    }

    private func chooseProjectLocation() {
        ProjectOpenPicker.presentProjectLocationPicker { result in
            viewModel.applyProjectLocationPickerResult(result)
        }
    }

    private func launcherSectionButton(_ section: ProjectOpeningSection) -> some View {
        let isActive = viewModel.selectedSection == section
        return Button {
            viewModel.selectSection(section)
        } label: {
            Text(section.title)
                .font(.system(size: 9))
                .foregroundColor(isActive ? .white : LauncherColor.muted)
                .frame(width: 58, height: 34)
                .background(RoundedRectangleShape(cornerRadius: 9).fill(isActive ? LauncherColor.glassSurface : .clear))
        }
        .buttonStyle(LauncherIconButtonStyle())
        .frame(width: 58, height: 34)
    }

    private func launcherListHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10))
            .foregroundColor(Color.white.opacity(0.3))
            .padding(.leading, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
    }

    private func projectRow(_ project: EditorProjectReference) -> some View {
        let isActive = viewModel.detailProject?.path == project.path

        return Button {
            viewModel.openRecentProject(project)
        } label: {
            ZStack(anchor: .leading) {
                if isActive {
                    LauncherColor.accentViolet
                        .frame(width: 2, height: 58)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(project.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("SPM")
                            .font(.system(size: 9))
                            .foregroundColor(LauncherColor.accentOrange)
                    }

                    Text(viewModel.abbreviatedPath(for: project))
                        .font(.system(size: 11))
                        .foregroundColor(LauncherColor.muted)
                        .lineLimit(1)
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .frame(width: ProjectOpeningLayout.explorerWidth, height: 58, alignment: .leading)
            }
        }
        .buttonStyle(LauncherPlainButtonStyle(active: isActive))
    }

    private func detailsList(_ project: EditorProjectReference?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            detailRow(label: "Engine Version", value: viewModel.engineVersion(for: project), highlighted: true)
            detailRow(label: "Build Core", value: "SwiftPM", highlighted: false)
            detailRow(label: "Project Path", value: project.map { viewModel.abbreviatedPath(for: $0) } ?? "Not selected", highlighted: false)
            detailRow(label: "Metadata", value: project == nil ? ".ada/project.json" : "Ready", highlighted: false)
            detailRow(label: "Last Opened", value: viewModel.lastOpenedText(for: project), highlighted: false)
        }
        .frame(maxWidth: .infinity)
        .background(LauncherColor.glassBorder)
        .overlay {
            RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.glassBorder, lineWidth: 1)
        }
    }

    private func detailRow(label: String, value: String, highlighted: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(LauncherColor.muted)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(highlighted ? LauncherColor.accentViolet : .white)
                .lineLimit(1)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .frame(height: ProjectOpeningLayout.detailRowHeight)
        .frame(maxWidth: .infinity)
        .background(LauncherColor.window)
    }
}

private struct LauncherPlainButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.state.isHighlighted ? Color.white.opacity(0.10) : (active ? Color.white.opacity(0.06) : .clear))
    }
}

private struct LauncherIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.state.isHighlighted ? 0.72 : 1.0)
    }
}

private struct LauncherGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.system(size: 15))
            .frame(width: ProjectOpeningLandingSpec.primaryButtonWidth, height: ProjectOpeningLandingSpec.primaryButtonHeight)
            .padding(.horizontal, 12)
            .glassEffect(
                configuration.state.isHighlighted
                    ? LauncherColor.landingButtonGlass.tint(LauncherColor.accentViolet.opacity(0.32))
                    : LauncherColor.landingButtonGlass,
                in: RoundedRectangleShape(cornerRadius: 14)
            )
    }
}

private struct LauncherGrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(LauncherColor.muted)
            .font(.system(size: 12))
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .frame(height: ProjectOpeningLandingSpec.footerButtonHeight)
    }
}

private struct LauncherInlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .frame(height: 30)
            .background(
                RoundedRectangleShape(cornerRadius: 8)
                    .fill(configuration.state.isHighlighted ? LauncherColor.glassSurface : Color.white.opacity(0.08))
            )
    }
}

private struct LauncherActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case outline
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(kind == .primary ? LauncherColor.background : .white)
            .font(.system(size: 13))
            .padding(.leading, 24)
            .padding(.trailing, 24)
            .frame(height: ProjectOpeningLayout.actionButtonHeight)
            .background(
                RoundedRectangleShape(cornerRadius: 10).fill(backgroundColor(isHighlighted: configuration.state.isHighlighted))
            )
            .overlay {
                RoundedRectangleShape(cornerRadius: 10).stroke(kind == .outline ? LauncherColor.glassBorder : .clear, lineWidth: 1)
            }
    }

    private func backgroundColor(isHighlighted: Bool) -> Color {
        switch kind {
        case .primary:
            return isHighlighted ? LauncherColor.accentViolet : .white
        case .outline:
            return isHighlighted ? LauncherColor.glassSurface : .clear
        }
    }
}
