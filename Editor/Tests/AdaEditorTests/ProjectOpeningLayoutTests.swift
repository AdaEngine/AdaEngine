@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Math
import Testing

@Suite("Project opening layout")
struct ProjectOpeningLayoutTests {
    @Test("columns and creation form stay inside the minimum window")
    @MainActor
    func contentFitsMinimumWindow() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let app = AppWorlds(main: World(name: "ProjectOpeningLayoutTests"))
            RenderWorldPlugin().setup(in: app)
        }
        let container = UIContainerView(
            rootView: ProjectOpeningView(autoOpenLastProject: false)
        )
        container.frame = Rect(
            x: 0,
            y: 0,
            width: ProjectOpeningLayout.windowWidth,
            height: ProjectOpeningLayout.windowHeight
        )
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()

        let sidebar = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.sidebar))
        let explorer = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.explorer))
        let detail = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.detail))
        let search = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.search))

        #expect(sidebar.absoluteFrame.width == ProjectOpeningLayout.sidebarWidth)
        #expect(explorer.absoluteFrame.minX == sidebar.absoluteFrame.maxX)
        #expect(explorer.absoluteFrame.width == ProjectOpeningLayout.explorerWidth)
        #expect(detail.absoluteFrame.minX == explorer.absoluteFrame.maxX)
        #expect(detail.absoluteFrame.maxX <= ProjectOpeningLayout.windowWidth)
        #expect(search.absoluteFrame.minY < 120)
        #expect(search.absoluteFrame.maxX <= explorer.absoluteFrame.maxX)

        _ = try container.uiTapNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.createProject))
        for _ in 0..<100 {
            await Task.yield()
            container.layoutIfNeeded()
            if (try? container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.createHeader))) != nil {
                break
            }
        }

        let header = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.createHeader))
        let description = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.createDescription))
        let projectType = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.projectType))
        let actions = try container.uiNode(matching: .accessibilityIdentifier(ProjectOpeningAccessibility.createActions))

        #expect(header.absoluteFrame.minY == ProjectOpeningLayout.detailPadding)
        #expect(header.absoluteFrame.maxY <= description.absoluteFrame.minY)
        #expect(description.absoluteFrame.maxY <= projectType.absoluteFrame.minY)
        #expect(actions.absoluteFrame.maxX <= ProjectOpeningLayout.windowWidth - ProjectOpeningLayout.detailPadding)
        #expect(actions.absoluteFrame.maxY <= ProjectOpeningLayout.windowHeight - ProjectOpeningLayout.detailPadding)
    }
}
