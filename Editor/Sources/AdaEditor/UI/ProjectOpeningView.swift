//
//  ProjectOpeningView.swift
//  AdaEngine
//

// swiftlint:disable type_body_length
@_spi(AdaEngine) import AdaEngine

private typealias LauncherColor = AdaColorPalette
enum ProjectOpeningLayout {
    static let usesNavigationSplitView = true
    static let detailUsesNavigationStack = true
    static let detailUsesSearchable = true
    static let windowWidth: Float = 1024
    static let windowHeight: Float = 700
    static let sidebarWidth: Float = 68
    static let explorerWidth: Float = 320
    static let detailWidth: Float = windowWidth - sidebarWidth - explorerWidth
    static let detailPadding: Float = 40
    static let detailContentWidth: Float = detailWidth - detailPadding * 2
    static let previewHeight: Float = 220
    static let detailRowHeight: Float = 44
    static let detailsRowCount: Float = 5
    static let actionButtonHeight: Float = 42
    static let actionButtonSpacing: Float = 12
    static let detailActionButtonCount = 0
    static let searchUsesGradient = false
    static let searchCapsuleWidth: Float = 280
    static let searchCapsuleHeight: Float = 46
    static let searchBottomPadding: Float = 20
    static let trafficLightOffsetY: Float = 0
    static let logoTopPadding: Float = 22
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
    static let isResizable = false
    static let hasShadow = true
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
    @State private var viewModel = ProjectOpeningViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var preferredCompactColumn = NavigationSplitViewColumn.detail
    @State private var didAttemptAutoOpenLastProject = false
    private let logoImage = ProjectOpeningAssets.loadAdaEngineLogo()

    init(autoOpenLastProject: Bool = true) {
        self.autoOpenLastProject = autoOpenLastProject
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar
                .navigationSplitViewColumnWidth(ProjectOpeningLayout.sidebarWidth)
        } content: {
            projectExplorer
                .navigationSplitViewColumnWidth(ProjectOpeningLayout.explorerWidth)
        } detail: {
            NavigationStack {
                projectDetail
                    .searchable(
                        text: viewModel.searchQueryBinding,
                        placement: .overlay(alignment: .topTrailing),
                        prompt: "Search projects..."
                    )
                    .navigationBarHidden(true)
                    .foregroundColor(.white)
            }
            .navigationSplitViewColumnWidth(ProjectOpeningLayout.detailWidth)
        }
        .frame(width: ProjectOpeningLayout.windowWidth, height: ProjectOpeningLayout.windowHeight)
        .background(LauncherColor.window)
        .frame(minWidth: ProjectOpeningLayout.windowWidth, minHeight: ProjectOpeningLayout.windowHeight)
        .background(LauncherColor.window)
        .onChange(of: viewModel.projectToOpenInEditorToken) { _, _ in
            guard let project = viewModel.consumeProjectToOpenInEditor() else {
                return
            }
            ProjectEditorLauncher.openEditor(for: project)
        }
        .onAppear {
            openLastProjectOnLaunchIfNeeded()
        }
    }

    private func openLastProjectOnLaunchIfNeeded() {
        guard autoOpenLastProject, !didAttemptAutoOpenLastProject else {
            return
        }

        didAttemptAutoOpenLastProject = true
        _ = viewModel.openLastProjectIfAvailable()
    }

    private var sidebar: some View {
        VStack(alignment: .center, spacing: 22) {
            if let logoImage {
                logoImage
                    .resizable()
                    .frame(width: 38, height: 38)
                    .padding(.bottom, 12)
            } else {
                Text("A")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .padding(.bottom, 12)
            }

            launcherNavItem("⌂", active: true)
            launcherNavItem("⇩", active: false)

            Spacer()
            Button {
                viewModel.statusMessage = "Project settings are not implemented yet."
            } label: {
                launcherNavItem("⚙", active: false)
            }
            .buttonStyle(LauncherIconButtonStyle())
        }
        .frame(width: ProjectOpeningLayout.sidebarWidth, height: ProjectOpeningLayout.windowHeight - 62)
        .padding(.top, ProjectOpeningLayout.logoTopPadding)
        .padding(.bottom, 24)
        .background(LauncherColor.sidebar)
    }

    private var projectExplorer: some View {
        VStack(alignment: .leading, spacing: 0) {
            launcherListHeader("Recents")
                .padding(.top, 20)

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
            .frame(width: ProjectOpeningLayout.explorerWidth, height: 390)

            launcherListHeader("Templates")
                .padding(.top, 12)

            Button {
                viewModel.beginCreateNewProject()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blank 3D Project")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("Clean slate with Ada metadata")
                        .font(.system(size: 10))
                        .foregroundColor(LauncherColor.muted.opacity(0.65))
                        .lineLimit(1)
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .frame(width: ProjectOpeningLayout.explorerWidth, height: 58, alignment: .leading)
            }
            .buttonStyle(LauncherPlainButtonStyle(active: false))

            Button {
                openProjectPicker()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open Existing Package")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text(viewModel.existingProjectPath.isEmpty ? "Paste path, then open" : viewModel.existingProjectPath)
                        .font(.system(size: 10))
                        .foregroundColor(LauncherColor.muted.opacity(0.65))
                        .lineLimit(1)
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .frame(width: ProjectOpeningLayout.explorerWidth, height: 58, alignment: .leading)
            }
            .buttonStyle(LauncherPlainButtonStyle(active: false))

            TextField("/path/to/Package", text: viewModel.existingProjectPathBinding)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .frame(width: 280, height: 36)
                .background(RoundedRectangleShape(cornerRadius: 8).fill(LauncherColor.input))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 8).stroke(LauncherColor.inputBorder, lineWidth: 1)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.leading, 20)
                .padding(.top, 8)

            Spacer()
        }
        .frame(width: ProjectOpeningLayout.explorerWidth, height: ProjectOpeningLayout.windowHeight)
        .background(LauncherColor.explorer)
        .overlay {
            HStack(spacing: 0) {
                Spacer()
                LauncherColor.glassBorder.frame(width: 1)
            }
        }
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
            .frame(height: 59, alignment: .topLeading)

            Spacer().frame(height: 32)

            ZStack {
                RoundedRectangleShape(cornerRadius: 12).fill(LauncherColor.preview)
                Text("NO RENDER PREVIEW AVAILABLE")
                    .font(.system(size: 11))
                    .foregroundColor(LauncherColor.muted.opacity(0.4))
            }
            .frame(width: ProjectOpeningLayout.detailContentWidth, height: ProjectOpeningLayout.previewHeight)
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
        .frame(width: ProjectOpeningLayout.detailWidth, height: ProjectOpeningLayout.windowHeight, alignment: .topLeading)
        .background(LauncherColor.window))
    }

    private var createProjectForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CREATE NEW PROJECT")
                .font(.system(size: 10))
                .foregroundColor(LauncherColor.accentViolet)

            Text("New Ada Project")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .padding(.top, 4)

            Text("Choose a project name and a destination folder. AdaEditor will create a new folder with the project files inside it.")
                .font(.system(size: 13))
                .foregroundColor(LauncherColor.muted)
                .lineLimit(3)
                .frame(width: ProjectOpeningLayout.detailContentWidth, alignment: .leading)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                createFormField(title: "Project Name") {
                    TextField("AdaGame", text: viewModel.projectNameBinding)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .frame(width: ProjectOpeningLayout.detailContentWidth, height: 44)
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
                    .frame(width: ProjectOpeningLayout.detailContentWidth, height: 44)
                    .background(RoundedRectangleShape(cornerRadius: 10).fill(LauncherColor.input))
                    .overlay {
                        RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.inputBorder, lineWidth: 1)
                    }
                }
            }
            .padding(.top, 38)

            Spacer()

            Text(viewModel.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(LauncherColor.muted)
                .lineLimit(2)
                .frame(width: ProjectOpeningLayout.detailContentWidth, height: 34, alignment: .leading)

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
            .frame(width: ProjectOpeningLayout.detailContentWidth)
        }
        .padding(ProjectOpeningLayout.detailPadding)
        .frame(width: ProjectOpeningLayout.detailWidth, height: ProjectOpeningLayout.windowHeight, alignment: .topLeading)
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
                .frame(width: ProjectOpeningLayout.detailContentWidth, alignment: .leading)
                .background(RoundedRectangleShape(cornerRadius: 10).fill(LauncherColor.input))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 10).stroke(LauncherColor.accentOrange.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .frame(width: ProjectOpeningLayout.detailContentWidth, alignment: .leading)
    }

    private func createFormField<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(LauncherColor.muted)
            content()
        }
    }

    private var emptyProjectLanding: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()

            if let logoImage {
                logoImage
                    .resizable()
                    .frame(width: ProjectOpeningLandingSpec.logoSize, height: ProjectOpeningLandingSpec.logoSize)
                    .padding(.bottom, 42)
            } else {
                Text("A")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .frame(width: ProjectOpeningLandingSpec.logoSize, height: ProjectOpeningLandingSpec.logoSize)
                    .background(RoundedRectangleShape(cornerRadius: 28).fill(LauncherColor.glassSurface))
                    .overlay {
                        RoundedRectangleShape(cornerRadius: 28).stroke(LauncherColor.glassBorder, lineWidth: 1)
                    }
                    .padding(.bottom, 42)
            }

            VStack(alignment: .center, spacing: 14) {
                Button {
                    viewModel.beginCreateNewProject()
                } label: {
                    Text(ProjectOpeningLandingSpec.primaryButtonTitles[0])
                }

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
        .frame(width: ProjectOpeningLayout.detailWidth, height: ProjectOpeningLayout.windowHeight)
        .background(LauncherColor.window)
    }

    private func openProjectPicker() {
        guard let projectURL = ProjectOpenPicker.pickProjectURL() else {
            viewModel.statusMessage = "Open project cancelled."
            return
        }

        viewModel.openProject(at: projectURL)
    }

    private func chooseProjectLocation() {
        guard let locationURL = ProjectOpenPicker.pickProjectLocationURL() else {
            viewModel.statusMessage = "Project location selection cancelled."
            return
        }

        viewModel.setProjectLocation(locationURL)
    }

    private func launcherNavItem(_ symbol: String, active: Bool) -> some View {
        Text(symbol)
            .font(.system(size: 20))
            .foregroundColor(active ? .white : LauncherColor.muted)
            .frame(width: 42, height: 42)
            .background(RoundedRectangleShape(cornerRadius: 10).fill(active ? LauncherColor.glassSurface : .clear))
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
                        .font(.system(size: 10))
                        .foregroundColor(LauncherColor.muted.opacity(0.6))
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
        .frame(width: ProjectOpeningLayout.detailContentWidth)
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
        .frame(width: ProjectOpeningLayout.detailContentWidth, height: ProjectOpeningLayout.detailRowHeight)
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
                LauncherColor.landingButtonGlass,
                in: RoundedRectangleShape(cornerRadius: 14)
            )
            .scaleEffect(configuration.state.isHighlighted ? 1.1 : 1.0)
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
