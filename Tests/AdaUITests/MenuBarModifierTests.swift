import AdaInput
import Math
import Testing
@testable import AdaPlatform
@testable import AdaUI

@MainActor
struct MenuBarModifierTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func menuBarModifierInsertsMenusWhenContainerBuildsMenu() {
        let fileMenu = UIMenu(title: "File")
        fileMenu.add(MenuItem(title: "Open"))
        let editMenu = UIMenu(title: "Edit")
        editMenu.add(MenuItem(title: "Copy"))

        let tester = ViewTester {
            Text("Root")
                .menuBar(fileMenu, editMenu)
        }
        let builder = RecordingMenuBuilder()

        tester.containerView.buildMenu(with: builder)

        #expect(builder.insertedMenus.map(\.title) == ["File", "Edit"])
    }

    #if os(Windows) || os(Linux)
    @Test
    func windowMenuUsesTheMostSpecificShortcutAndDisabledState() {
        var saved = 0
        var savedAll = 0
        let save = MenuItem(title: "Save", action: UIEventAction { saved += 1 }, keyEquivalent: .s, keyEquivalentModifierMask: .control)
        let saveAll = MenuItem(title: "Save All", action: UIEventAction { savedAll += 1 }, keyEquivalent: .s, keyEquivalentModifierMask: [.control, .shift])
        let menu = UIMenu(title: "File")
        menu.add(save)
        menu.add(saveAll)
        let tester = ViewTester { Text("Root").menuBar(menu) }
            .setSize(Size(width: 640, height: 400)).performLayout()
        #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.MenuBar") != nil)
        #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.MenuBar." + menu.id) != nil)
        tester.sendKeyEvent(.s, modifiers: [.control, .shift], time: 0)
        #expect(saved == 0 && savedAll == 1)
        tester.sendKeyEvent(.s, modifiers: .control, time: 0.1)
        #expect(saved == 1 && savedAll == 1)
        save.isEnabled = false
        tester.sendKeyEvent(.s, modifiers: .control, time: 0.2)
        #expect(saved == 1)
    }
    #endif
}

@MainActor
private final class RecordingMenuBuilder: UIMenuBuilder {
    var insertedMenus: [UIMenu] = []
    var removedMenus: [UIMenu.ID] = []
    var didRequestUpdate = false

    func insert(_ menu: UIMenu) {
        insertedMenus.append(menu)
    }

    func remove(_ menu: UIMenu.ID) {
        removedMenus.append(menu)
    }

    func setNeedsUpdate() {
        didRequestUpdate = true
    }

    func updateIfNeeded() {}
}
