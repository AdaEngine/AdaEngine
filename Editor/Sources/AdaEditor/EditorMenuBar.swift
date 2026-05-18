//
//  EditorMenuBar.swift
//  AdaEngine
//

import AdaEngine

@MainActor
enum EditorMenuBar {
    static func makeMenus() -> [UIMenu] {
        [
            fileMenu(),
            editMenu(),
            viewMenu(),
            windowMenu(),
            helpMenu()
        ]
    }

    private static func fileMenu() -> UIMenu {
        menu("File", items: [
            item("New Project", key: .n),
            item("Open Project...", key: .o),
            MenuItem.separator,
            item("Close Window", key: .w),
            item("Save", key: .s),
            item("Save As...", key: .s, modifiers: [.main, .shift])
        ])
    }

    private static func editMenu() -> UIMenu {
        menu("Edit", items: [
            item("Undo", key: .z),
            item("Redo", key: .z, modifiers: [.main, .shift]),
            MenuItem.separator,
            item("Cut", key: .x),
            item("Copy", key: .c),
            item("Paste", key: .v),
            item("Delete", key: .delete, modifiers: []),
            MenuItem.separator,
            item("Select All", key: .a)
        ])
    }

    private static func viewMenu() -> UIMenu {
        menu("View", items: [
            item("Reload Preview", key: .r),
            MenuItem.separator,
            item("Show Project Sidebar", key: .num1, modifiers: [.main, .alt]),
            item("Show Inspector", key: .num2, modifiers: [.main, .alt]),
            item("Show Console", key: .num3, modifiers: [.main, .alt]),
            MenuItem.separator,
            item("Enter Full Screen", key: .f, modifiers: [.main, .control])
        ])
    }

    private static func windowMenu() -> UIMenu {
        menu("Window", items: [
            item("Minimize", key: .m),
            item("Zoom"),
            MenuItem.separator,
            item("Bring All to Front")
        ])
    }

    private static func helpMenu() -> UIMenu {
        menu("Help", items: [
            item("AdaEngine Editor Help"),
            item("AdaEngine Documentation")
        ])
    }

    private static func menu(_ title: String, items: [MenuItem]) -> UIMenu {
        let menu = UIMenu(title: title)
        for item in items {
            menu.add(item)
        }

        return menu
    }

    private static func item(
        _ title: String,
        key: KeyCode? = nil,
        modifiers: KeyModifier? = .main
    ) -> MenuItem {
        let menuItem = MenuItem(
            title: title,
            action: UIEventAction {},
            keyEquivalent: key,
            keyEquivalentModifierMask: modifiers
        )
        menuItem.isEnabled = false
        return menuItem
    }
}
