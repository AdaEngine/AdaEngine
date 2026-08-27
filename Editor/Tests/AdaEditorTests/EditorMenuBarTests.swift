import Testing
@testable import AdaEditor

@MainActor
struct EditorMenuBarTests {
    @Test
    func menuBarContainsEditorWorkflowMenus() {
        let menus = EditorMenuBar.makeMenus()

        #expect(menus.map(\.title) == ["File", "Edit", "View", "Project", "Build", "Code", "Window", "Help"])
        #expect(menus.allSatisfy { !$0.items.isEmpty })
        #expect(menus.flatMap(\.items).filter { !$0.isSeparator }.allSatisfy { $0.isEnabled })
    }

    @Test
    func workflowMenusExposeExpectedActionsAndShortcuts() throws {
        let menus = EditorMenuBar.makeMenus()
        let file = try #require(menus.first { $0.title == "File" })
        let build = try #require(menus.first { $0.title == "Build" })
        let code = try #require(menus.first { $0.title == "Code" })

        #expect(file.items.map(\.title).contains("New File"))
        #expect(file.items.map(\.title).contains("Open Project..."))
        #expect(file.items.map(\.title).contains("Save All"))
        #expect(build.items.map(\.title).contains("Build Project"))
        #expect(build.items.map(\.title).contains("Run Tests"))
        #expect(code.items.map(\.title).contains("Rebuild Preview"))
        #expect(file.items.first { $0.title == "Save" }?.keyEquivalent == .s)
        #expect(build.items.first { $0.title == "Build Project" }?.keyEquivalent == .b)
    }
}
