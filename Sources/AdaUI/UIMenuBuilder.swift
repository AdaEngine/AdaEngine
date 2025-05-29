//
//  UIMenuBuilder.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 04.08.2024.
//

import AdaUtils
import AdaInput
import AdaRender

@MainActor
public protocol UIMenuBuilder: AnyObject {
    func insert(_ menu: UIMenu)
    func remove(_ menu: UIMenu.ID)

    func setNeedsUpdate()
    func updateIfNeeded()
}

public final class MenuItem: Identifiable {

    private static let separatorTitle = "_SEPARATOR_"
    nonisolated(unsafe) public static let separator: MenuItem = MenuItem()
    
    public let title: String
    /// The menu item’s image.
    public var image: Image?
    public var action: UIEventAction?
    
    public var keyEquivalent: KeyCode?
    public var keyEquivalentModifierMask: KeyModifier?
    
    public var isEnabled: Bool = true
    
    public private(set) weak var menu: UIMenu?
    
    public var isSeparator: Bool {
        self.title == Self.separatorTitle
    }

    init() {
        self.title = Self.separatorTitle
        self.isEnabled = false
    }
    
    public init(
        title: String,
        image: Image? = nil,
        action: UIEventAction? = nil,
        keyEquivalent: KeyCode? = nil,
        keyEquivalentModifierMask: KeyModifier? = nil
    ) {
        self.title = title
        self.image = image
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.keyEquivalentModifierMask = keyEquivalentModifierMask
    }
    
    func setMenuOwner(_ owner: UIMenu) {
        self.menu = owner
    }
    
    public private(set) weak var parent: MenuItem?

    public var hasSubmenu: Bool {
        return submenu != nil
    }
    public private(set) var submenu: UIMenu?

    public func setSebmenu(_ menu: UIMenu) {
        self.submenu = menu
        menu.items.forEach {
            $0.parent = self
        }
    }

    public func removeSubmenu() {
        self.submenu = nil
    }
}

public class UIMenu: Identifiable {

    public let id: String
    public let title: String

    public private(set) weak var menuBuilder: UIMenuBuilder?

    public private(set) weak var parent: UIMenu?
    public private(set) var items: [MenuItem] = []

    public init(title: String) {
        self.id = title
        self.title = title
    }

    public func add(_ item: MenuItem) {
        self.items.append(item)
        item.setMenuOwner(self)
    }

    public func remove(_ item: MenuItem) {
        self.items.removeAll(where: { $0.id == item.id })
    }

    public func setMenuOwner(_ owner: UIMenuBuilder) {
        self.menuBuilder = owner
    }

    func update() {
        
    }
}
