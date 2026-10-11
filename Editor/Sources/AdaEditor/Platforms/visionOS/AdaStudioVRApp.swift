#if os(visionOS)
    import AdaEngine
    import AdaEngineEmbeddable
    import CompositorServices
    import Foundation
    import Observation
    import SwiftUI
    import UniformTypeIdentifiers

    @available(visionOS 26.0, *)
    @main
    struct AdaStudioVRApp: SwiftUI.App {
        @SwiftUI.State private var session = EditorVRSession()
        @SwiftUI.State private var immersion: ImmersionStyle = .full
        var body: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Ada Studio VR", id: "studio-toolbar") {
                EditorVRWorkspaceShell(session: session)
            }
            .defaultSize(width: 1024, height: 700)
            .windowStyle(.plain)
            .windowResizability(.contentSize)

            SwiftUI.WindowGroup("Play", id: EditorVRPlaySession.windowID, for: Bool.self) { _ in
                EditorVRPlayWindow(workspace: session.workspace)
            } defaultValue: { true }
            .defaultSize(width: 1024, height: 720).windowStyle(.plain).windowResizability(.contentSize)

            hierarchyWindow
            inspectorWindow
            projectWindow
            assetsWindow
            navigationWindow
            SwiftUI.WindowGroup("Voice with Ada", id: EditorVRPanel.voice.windowID, for: Bool.self) { _ in
                EditorVRVoiceBubble(workspace: session.workspace)
            } defaultValue: { true }
            .defaultSize(width: 320, height: 380).windowStyle(.plain).windowResizability(.contentSize)
                .defaultWindowPlacement { _, context in
                    if session.workspace.isImmersed, let dock = context.windows.first(where: { $0.id == "studio-toolbar" }) {
                        return WindowPlacement(.above(dock))
                    }
                    return WindowPlacement()
                }
            studioWindow(.studio, title: "Ada Studio", width: 1600, height: 900)
            studioWindow(.files, title: "Files", width: 1600, height: 900)
            studioWindow(.code, title: "Editor", width: 1600, height: 900)
            studioWindow(.console, title: "Console", width: 920, height: 420)
            studioWindow(.agent, title: "Agent", width: 540, height: 740)
            SwiftUI.WindowGroup("Settings", id: EditorVRPanel.settings.windowID, for: Bool.self) { _ in
                EditorVRPanelHost(workspace: session.workspace, panel: .settings, width: 1000, height: 720) {
                    EditorVRStudioPanel(workspace: session.workspace, panel: .settings)
                }
            } defaultValue: { true }
            .defaultSize(width: 1000, height: 720).windowStyle(.plain).windowResizability(.contentSize)

            ImmersiveSpace(id: "studio-scene") {
                CompositorLayer(configuration: ImmersiveLayerConfiguration()) { layer in
                    Task { @MainActor in await session.run(layer: layer) }
                }
            }.immersionStyle(selection: $immersion, in: .full).upperLimbVisibility(.visible)
        }

        private func studioWindow(_ panel: EditorVRPanel, title: String, width: Double, height: Double) -> some SwiftUI.Scene {
            SwiftUI.WindowGroup(title, id: panel.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: panel, width: width, height: height) {
                    EditorVRStudioPanel(workspace: session.workspace, panel: panel)
                }
            }.defaultSize(width: width, height: height).windowStyle(.plain).windowResizability(.contentSize)
        }

        private var hierarchyWindow: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Scene", id: EditorVRPanel.hierarchy.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: .hierarchy, width: 360, height: 540) {
                    EditorVRHierarchyPanel(workspace: session.workspace)
                }
            }.defaultSize(width: 360, height: 540).windowStyle(.plain).windowResizability(.contentSize)
                .defaultWindowPlacement { _, context in
                    if let dock = context.windows.first(where: { $0.id == "studio-toolbar" }) {
                        return WindowPlacement(.leading(dock))
                    }
                    return WindowPlacement()
                }
        }

        private var inspectorWindow: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Inspector", id: EditorVRPanel.inspector.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: .inspector, width: 400, height: 600) {
                    EditorInspectorSidebar(viewModel: session.workspace.inspector, showsTitle: false)
                        .disabled(session.workspace.isManipulating || session.workspace.document?.isReadOnly == true)
                }
            }.defaultSize(width: 400, height: 600).windowStyle(.plain).windowResizability(.contentSize)
                .defaultWindowPlacement { _, context in
                    if let dock = context.windows.first(where: { $0.id == "studio-toolbar" }) {
                        return WindowPlacement(.trailing(dock))
                    }
                    return WindowPlacement()
                }
        }

        private var projectWindow: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Project", id: EditorVRPanel.project.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: .project, width: 420, height: 440) {
                    EditorVRProjectPanel(
                        workspace: session.workspace,
                        openProject: { session.importsProject = true },
                        createProject: session.createProject,
                        enter: { session.requestsEntry = true },
                        leave: { session.requestsLeave = true },
                        openPanel: { session.requestedPanel = $0 }
                    )
                }
            }.defaultSize(width: 420, height: 440).windowStyle(.plain).windowResizability(.contentSize)
        }

        private var assetsWindow: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Assets", id: EditorVRPanel.assets.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: .assets, width: 430, height: 460) {
                    EditorVRAssetsPanel(workspace: session.workspace)
                }
            }.defaultSize(width: 430, height: 460).windowStyle(.plain).windowResizability(.contentSize)
        }

        private var navigationWindow: some SwiftUI.Scene {
            SwiftUI.WindowGroup("Navigation", id: EditorVRPanel.navigation.windowID) {
                EditorVRPanelHost(workspace: session.workspace, panel: .navigation, width: 380, height: 300) {
                    EditorVRNavigationPanel(workspace: session.workspace, moveViewer: session.move, focusSelection: session.focusSelection)
                }
            }.defaultSize(width: 380, height: 300).windowStyle(.plain).windowResizability(.contentSize)
        }
    }

    @available(visionOS 26.0, *)
    @Observable
    @MainActor
    final class EditorVRSession {
        let workspace = EditorVRWorkspace()
        let launcher = ProjectOpeningViewModel()
        var requestedWelcome: Bool?
        var launchError: String?
        var needsDismissal = false
        var requestedPanel: EditorVRPanel?
        var requestedProject: EditorProjectReference?
        var importsProject = false
        var requestsEntry = false
        var requestsLeave = false
        @ObservationIgnored private var renderer: AdaImmersiveRenderer?
        @ObservationIgnored private let desktopInput = EditorVRDesktopInput()
        var viewerPosition: Vector3? { renderer?.viewerPosition }
        @ObservationIgnored private var task: Task<Void, Never>?

        init() {
            ProjectEditorLauncher.nativeProjectOpener = { [weak self] project in self?.requestedProject = project }
            ProjectEditorLauncher.nativeWelcomeOpener = { [weak self] create in self?.requestedWelcome = create }
        }

        func run(layer: LayerRenderer) async {
            guard renderer == nil, workspace.document != nil else {
                needsDismissal = true
                return
            }
            workspace.isOpening = true
            let host = AdaImmersiveRenderer(layerRenderer: layer, assetBundle: .editor)
            renderer = host
            host.placeViewer(at: [0, 1.6, -1.5])
            workspace.runtimeAccess = { [weak host] action in host?.performWorldAccess(action) }
            host.onFrame = { [weak self] in self?.workspace.frame($0) }
            desktopInput.canScroll = { [weak self] in
                guard let self else { return false }
                return self.workspace.isImmersed && !self.workspace.isEditingText && !self.workspace.isPointerOverPanel
            }
            desktopInput.start()
            host.onInput = { [weak self, weak host] world, eye, size in
                guard let camera = eye.components[Camera.self], let pose = eye.components[Transform.self] else {
                    return
                }
                if let self {
                    var desktop = self.desktopInput.sample()
                    let offset = self.workspace.navigate(world, keys: desktop.keys, wheel: desktop.wheel)
                    host?.translateViewer(by: offset)
                }
                self?.workspace.input(world, camera: .init(projection: camera.projection, transform: pose, renderGraphLabel: .main3D), size: size)
            }
            host.onDrawOverlay = { [weak self] world, eye, size in
                guard let camera = eye.components[Camera.self], let pose = eye.components[Transform.self] else {
                    return []
                }
                return self?.workspace.overlay(world, camera: .init(projection: camera.projection, transform: pose, renderGraphLabel: .main3D), size: size) ?? []
            }
            let run = Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                defer {
                    desktopInput.stop()
                    workspace.finishImmersion()
                    renderer = nil
                    task = nil
                }
                do {
                    try await host.run { world in
                        workspace.attachWorld(world)
                        workspace.isImmersed = true
                        workspace.isOpening = false
                    }
                } catch is CancellationError {
                } catch {
                    workspace.message = "Immersive editor stopped: \(error.localizedDescription)"
                    print("[AdaStudioVR] \(error)")
                    needsDismissal = true
                }
            }
            task = run
            await run.value
        }

        func createProject() { requestedWelcome = true }

        func stop() { task?.cancel() }

        func move(by offset: Vector3) {
            guard !workspace.isManipulating, let renderer else {
                return
            }
            renderer.translateViewer(by: offset)
        }

        func focusSelection() {
            guard !workspace.isManipulating, let renderer else {
                return
            }
            renderer.performWorldAccess { [weak self, weak renderer] _ in
                guard let self, let renderer, let id = workspace.viewport.selectedEditorID,
                    let entity = workspace.viewport.runtimeEntity(for: id), let transform = entity.components[Transform.self]
                else {
                    return
                }
                var matrix = transform.matrix
                var parent = entity.parent
                while let current = parent {
                    matrix = (current.components[Transform.self]?.matrix ?? .identity) * matrix
                    parent = current.parent
                }
                let bounds = entity.components[SpatialGrabbable.self]
                let center = (matrix * Vector4(bounds?.center ?? .zero, 1)).xyz
                let scale = matrix.scale
                let distance = max(1.5, (bounds?.halfExtents ?? Vector3.one).length * max(scale.x, max(scale.y, scale.z)) * 2)
                renderer.placeViewer(at: center + Vector3(0, 0, -distance))
            }
        }
    }

#endif
