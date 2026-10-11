#if os(visionOS)
    import AdaEngine
    import AdaEngineEmbeddable
    import Foundation
    import SwiftUI
    import UniformTypeIdentifiers


    @available(visionOS 26.0, *)
    struct EditorVRWorkspaceShell: SwiftUI.View {
        let session: EditorVRSession
        @SwiftUI.State private var wideResizeRequest = 0
        @SwiftUI.Environment(\.openImmersiveSpace) private var openSpace
        @SwiftUI.Environment(\.dismissImmersiveSpace) private var dismissSpace
        @SwiftUI.Environment(\.openWindow) private var openWindow
        @SwiftUI.Environment(\.dismissWindow) private var dismissWindow
        @SwiftUI.Environment(\.scenePhase) private var scenePhase

        var body: some SwiftUI.View {
            SwiftUI.VStack(spacing: 0) {
                if let error = session.launchError {
                    SwiftUI.Text(error).font(.callout).foregroundStyle(.red).padding(12)
                }
                AdaUIHost(assetBundle: .editor, onError: { session.workspace.message = $0.localizedDescription },
                    onTextInputFocusChanged: { session.workspace.setTextInputFocus($0, host: "studio-toolbar") }) {
                    AdaEngine.Group {
                        if session.workspace.isImmersed {
                            EditorVRDock(workspace: session.workspace, togglePanel: togglePanel, focusSelection: session.focusSelection)
                        } else if let editor = session.workspace.studio, let project = session.workspace.project {
                            EditorView(project: project, viewModel: editor, usesNativeOrnaments: true)
                        } else {
                            AdaEngine.GeometryReader { geometry in
                                ProjectOpeningView(autoOpenLastProject: false, viewModel: session.launcher, viewportHeight: geometry.size.height)
                            }
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .environment(\.theme, .adaEditor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(
                minWidth: minimumWindowWidth, idealWidth: windowWidth, maxWidth: maximumWindowWidth,
                minHeight: minimumWindowHeight, idealHeight: windowHeight, maxHeight: maximumWindowHeight
            )
            .background {
                EditorVRWindowResize(request: wideResizeRequest, size: CGSize(width: 2200, height: 900),
                    onError: { session.workspace.message = $0.localizedDescription })
                    .frame(width: 0, height: 0)
            }
            .glassBackgroundEffect(in: SwiftUI.RoundedRectangle(cornerRadius: 28))
            .modifier(EditorVRStudioOrnaments(workspace: session.workspace, visible: !session.workspace.isImmersed,
                resize: { wideResizeRequest += 1 }, enter: { session.requestsEntry = true }))
            .ornament(visibility: session.workspace.isImmersed ? .visible : .hidden,
                attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
                SwiftUI.Button {
                    session.requestsLeave = true
                } label: {
                    SwiftUI.Label("Exit Immersive", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.borderless).controlSize(.large)
                .disabled(session.requestsLeave)
                .accessibilityIdentifier("AdaEditor.VR.ExitImmersive")
                .padding(14).glassBackgroundEffect(in: SwiftUI.Capsule()).padding(.top, 16)
            }
            .fileImporter(
                isPresented: SwiftUI.Binding(get: { session.importsProject }, set: { session.importsProject = $0 }),
                allowedContentTypes: [.folder, UTType(exportedAs: "org.adaengine.project", conformingTo: .package)],
                allowsMultipleSelection: false
            ) { result in
                do {
                    if let url = try result.get().first { session.launcher.openProject(at: url) }
                } catch { session.workspace.message = error.localizedDescription }
            }
            .onOpenURL { url in
                session.launcher.openProject(at: url)
            }
            .task { closePanels() }
            .onChange(of: session.launcher.projectToOpenInEditorToken) { _, _ in
                // Native URL/debug routes can arrive before the embedded chooser's first frame.
                // Both hosts consume the same one-shot request, so Studio opens once.
                if let project = session.launcher.consumeProjectToOpenInEditor() {
                    session.requestedProject = project
                }
            }
            .onChange(of: session.workspace.playSession?.id) { _, id in
                if id != nil { openWindow(id: EditorVRPlaySession.windowID, value: true) }
                else { dismissWindow(id: EditorVRPlaySession.windowID) }
            }
            .onChange(of: session.requestedProject) { _, project in
                if let project {
                    Task { @MainActor in
                        guard session.workspace.workbench.saveAllDocuments() else {
                            session.launchError = "Save the current project before switching."
                            session.requestedProject = nil
                            return
                        }
                        if session.workspace.isImmersed {
                            await dismissSpace()
                            session.stop()
                            for _ in 0..<100 where session.workspace.isImmersed { try? await Task.sleep(for: .milliseconds(50)) }
                        }
                        do {
                            session.launchError = nil
                            closePanels()
                            try session.workspace.openProject(at: EditorProjectStore().resolveProjectURL(for: project))
                        } catch { session.launchError = error.localizedDescription }
                        session.requestedProject = nil
                    }
                }
            }
            .onChange(of: session.requestedWelcome) { _, create in
                guard let create else {
                    return
                }
                Task { @MainActor in
                    if session.workspace.isImmersed {
                        // The compositor needs rendering alive while it dismisses its space.
                        await dismissSpace()
                        session.stop()
                        for _ in 0..<100 where session.workspace.isImmersed { try? await Task.sleep(for: .milliseconds(50)) }
                    }
                    if session.workspace.closeProject() {
                        session.launchError = nil
                        closePanels()
                        session.launcher.reloadRecentProjects()
                        if create { session.launcher.beginCreateNewProject() }
                    } else { session.launchError = "Save the current project before closing it." }
                    session.requestedWelcome = nil
                }
            }
            .onChange(of: session.workspace.studio?.settingsPresentationToken) { _, _ in
                if session.workspace.studio?.requestedSettingsSection != nil { showPanel(.settings) }
            }
            .onChange(of: session.workspace.activatedPalmPanel) { _, panel in
                if let panel {
                    showPanel(panel)
                    session.workspace.activatedPalmPanel = nil
                }
            }
            .onChange(of: session.requestedPanel) { _, panel in
                if let panel {
                    showPanel(panel)
                    session.requestedPanel = nil
                }
            }
            .onChange(of: session.requestsEntry) { _, requested in
                if requested {
                    Task { @MainActor in
                        await enter()
                        session.requestsEntry = false
                    }
                }
            }
            .onChange(of: session.requestsLeave) { _, requested in
                if requested {
                    Task { @MainActor in
                        // The compositor needs rendering alive while it dismisses its space.
                        await dismissSpace()
                        session.stop()
                        session.requestsLeave = false
                    }
                }
            }
            .onChange(of: session.workspace.isImmersed) { _, immersed in
                if immersed { openWindow(id: EditorVRPanel.voice.windowID) }
                else { dismissWindow(id: EditorVRPanel.voice.windowID) }
            }
            .onChange(of: session.needsDismissal) { _, requested in
                if requested {
                    Task { @MainActor in
                        await dismissSpace()
                        session.needsDismissal = false
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .background { session.stop() } }
        }

        private var windowWidth: Double {
            session.workspace.isImmersed ? 824 : session.workspace.project == nil ? 1024 : 1600
        }
        private var windowHeight: Double {
            session.workspace.isImmersed ? 132 : session.workspace.project == nil ? 700 : 900
        }

        private var minimumWindowWidth: Double { session.workspace.isImmersed ? 824 : session.workspace.project == nil ? 900 : 1000 }
        private var maximumWindowWidth: Double { session.workspace.isImmersed ? 824 : session.workspace.project == nil ? 1600 : 2800 }
        private var minimumWindowHeight: Double { session.workspace.isImmersed ? 132 : 600 }
        private var maximumWindowHeight: Double { session.workspace.isImmersed ? 132 : session.workspace.project == nil ? 1000 : 1600 }

        private func closePanels() {
            dismissWindow(id: EditorVRPlaySession.windowID)
            for panel in EditorVRPanel.allCases { dismissWindow(id: panel.windowID) }
        }

        private func showPanel(_ panel: EditorVRPanel) {
            if panel == .settings {
                guard session.workspace.prepareSettingsWindow() else {
                    return
                }
                // A single scene value focuses an existing Settings window rather than duplicating it.
                openWindow(id: panel.windowID, value: true)
                return
            }
            guard !session.workspace.presentedPanels.contains(panel) else {
                return
            }
            openWindow(id: panel.windowID)
        }

        private func togglePanel(_ panel: EditorVRPanel) {
            if session.workspace.presentedPanels.contains(panel) {
                dismissWindow(id: panel.windowID)
            } else {
                openWindow(id: panel.windowID)
            }
        }


        @MainActor
        private func enter() async {
            guard session.workspace.document != nil, !session.workspace.isOpening, !session.workspace.isImmersed else {
                return
            }
            session.workspace.isOpening = true
            switch await openSpace(id: "studio-scene") {
            case .opened: break
            case .userCancelled: session.workspace.isOpening = false
            case .error:
                session.workspace.isOpening = false
                session.workspace.message = "Could not open the immersive editor."
            @unknown default: session.workspace.isOpening = false
            }
        }
    }
#endif
