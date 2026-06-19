//
//  ContextMenuPlugin.swift
//  AdaEngine
//
//  Created by Codex on 29.04.2026.
//

import AdaApp
import AdaECS
import AdaRender
import AdaScene
@_spi(Internal) import AdaUI
import AdaUtils
import Math

public struct ContextMenuPlugin: Plugin {
    public init() {}

    public func setup(in app: AppWorlds) {
        ContextMenuPresentationCenter.present = { presentation in
            ContextMenuPresenter.present(presentation, in: app)
        }
        ContextMenuPresentationCenter.dismissAll = {
            ContextMenuPresenter.dismissAll()
        }
        ContextMenuPresentationCenter.dismissForInteraction = { window in
            ContextMenuPresenter.dismissForInteraction(in: window)
        }
    }
}

@MainActor
private enum ContextMenuPresenter {
    private static var activeSession: ContextMenuSession?

    static func present(_ presentation: ContextMenuPresentation, in app: AppWorlds) {
        guard !presentation.items.isEmpty else { return }

        activeSession?.closeAll()

        let session = ContextMenuSession(
            sourceWindow: presentation.sourceWindow,
            onDismiss: presentation.onDismiss
        )
        activeSession = session
        let window = makeWindow(
            items: presentation.items,
            origin: menuOrigin(for: presentation, menuSize: menuSize(for: presentation.items)),
            app: app,
            session: session,
            level: 0
        )
        session.setWindow(window, at: 0)
        window.showWindow(makeFocused: true)
    }

    @discardableResult
    static func dismissAll() -> Bool {
        guard let session = activeSession else {
            return false
        }

        session.closeAll()
        activeSession = nil
        return true
    }

    static func dismissForInteraction(in window: UIWindow?) {
        guard let activeSession, let window, !activeSession.contains(window) else {
            return
        }

        activeSession.closeAll()
        self.activeSession = nil
    }

    fileprivate static func presentSubmenu(
        items: [ContextMenuPresentation.Item],
        from parentWindow: UIWindow,
        parentLevel: Int,
        rowIndex: Int,
        in session: ContextMenuSession
    ) {
        guard !items.isEmpty else { return }

        session.closeSubmenus(from: parentLevel + 1)
        let level = parentLevel + 1
        let size = menuSize(for: items)
        let origin = submenuOrigin(parentWindow: parentWindow, rowIndex: rowIndex, menuSize: size, sourceWindow: session.sourceWindow)
        let window = makeWindow(
            items: items,
            origin: origin,
            app: session.app,
            session: session,
            level: level
        )
        session.setWindow(window, at: level)
        window.showWindow(makeFocused: false)
    }

    fileprivate static func closeSubmenus(from level: Int, in session: ContextMenuSession) {
        session.closeSubmenus(from: level)
    }

    fileprivate static func performAction(_ action: (() -> Void)?, in session: ContextMenuSession) {
        session.closeAll()
        if activeSession === session {
            activeSession = nil
        }
        action?()
    }

    private static func makeWindow(
        items: [ContextMenuPresentation.Item],
        origin: Point,
        app: AppWorlds,
        session: ContextMenuSession,
        level: Int
    ) -> UIWindow {
        let size = menuSize(for: items)
        let window = UIWindow(
            configuration: UIWindow.Configuration(
                title: "",
                frame: Rect(origin: origin, size: size),
                minimumSize: size,
                chrome: .borderless,
                background: .transparent,
                level: .floating,
                collectionBehavior: .allSpacesStationary,
                makeKey: level == 0
            )
        )

        session.app = app
        let container = UIContainerView(
            rootView: ContextMenuWindowContent(
                items: items,
                window: window,
                session: session,
                level: level
            )
        )
        container.backgroundColor = Color.clear
        container.autoresizingRules = UIView.AutoresizingRule([.flexibleWidth, .flexibleHeight])
        container.frame = Rect(origin: .zero, size: size)
        window.addSubview(container)
        container.layoutSubviews()

        var camera = Camera(window: .windowId(window.id))
        camera.backgroundColor = Color(red: 0, green: 0, blue: 0, alpha: 0)
        window.runtimeCameraEntity = app.spawn(bundle: Camera2D(camera: camera))
        return window
    }

    private static func menuSize(for items: [ContextMenuPresentation.Item]) -> Size {
        let longestTitleCount = items.map(\.title.count).max() ?? 0
        let width = max(180, min(320, Float(longestTitleCount * 8 + 40)))
        let height = Float(items.count) * ContextMenuMetrics.rowHeight + ContextMenuMetrics.verticalPadding * 2
        return Size(width: width, height: height)
    }

    private static func menuOrigin(for presentation: ContextMenuPresentation, menuSize: Size) -> Point {
        guard let sourceWindow = presentation.sourceWindow,
              let systemWindow = sourceWindow.systemWindow
        else {
            return presentation.location
        }

        let sourceOrigin = systemWindow.position
        let sourceSize = sourceWindow.frame.size
        var origin = Point(
            x: sourceOrigin.x + presentation.location.x,
            y: sourceOrigin.y + sourceSize.height - presentation.location.y - menuSize.height
        )

        if let screenSize = sourceWindow.screen?.size {
            origin.x = min(max(0, origin.x), max(0, screenSize.width - menuSize.width))
            origin.y = min(max(0, origin.y), max(0, screenSize.height - menuSize.height))
        }

        return origin
    }

    private static func submenuOrigin(
        parentWindow: UIWindow,
        rowIndex: Int,
        menuSize: Size,
        sourceWindow: UIWindow?
    ) -> Point {
        guard let systemWindow = parentWindow.systemWindow else {
            return .zero
        }

        let parentOrigin = systemWindow.position
        let parentSize = parentWindow.frame.size
        var origin = Point(
            x: parentOrigin.x + parentSize.width - ContextMenuMetrics.submenuOverlap,
            y: parentOrigin.y + parentSize.height - ContextMenuMetrics.verticalPadding - Float(rowIndex) * ContextMenuMetrics.rowHeight - menuSize.height
        )

        if let screenSize = (sourceWindow ?? parentWindow).screen?.size {
            if origin.x + menuSize.width > screenSize.width {
                origin.x = parentOrigin.x - menuSize.width + ContextMenuMetrics.submenuOverlap
            }
            origin.x = min(max(0, origin.x), max(0, screenSize.width - menuSize.width))
            origin.y = min(max(0, origin.y), max(0, screenSize.height - menuSize.height))
        }

        return origin
    }
}

@MainActor
private final class ContextMenuSession {
    weak var sourceWindow: UIWindow?
    var app: AppWorlds!
    private var onDismiss: (() -> Void)?
    private var windowsByLevel: [Int: UIWindow] = [:]

    init(sourceWindow: UIWindow?, onDismiss: (() -> Void)?) {
        self.sourceWindow = sourceWindow
        self.onDismiss = onDismiss
    }

    func setWindow(_ window: UIWindow, at level: Int) {
        windowsByLevel[level] = window
    }

    func contains(_ window: UIWindow) -> Bool {
        windowsByLevel.values.contains { $0 === window }
    }

    func closeSubmenus(from level: Int) {
        for closeLevel in windowsByLevel.keys.filter({ $0 >= level }).sorted(by: >) {
            windowsByLevel.removeValue(forKey: closeLevel)?.close()
        }
    }

    func closeAll() {
        closeSubmenus(from: 0)
        onDismiss?()
        onDismiss = nil
    }
}

private enum ContextMenuMetrics {
    static let rowHeight: Float = 32
    static let verticalPadding: Float = 6
    static let submenuOverlap: Float = 4
}

private struct ContextMenuWindowContent: View {
    let items: [ContextMenuPresentation.Item]
    weak var window: UIWindow?
    let session: ContextMenuSession
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<items.count) { index in
                menuRow(for: items[index], at: index)
            }
        }
        .padding(.vertical, ContextMenuMetrics.verticalPadding)
        .frame(width: rowWidth + 24)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(backgroundColor))
    }

    private func menuRow(for item: ContextMenuPresentation.Item, at index: Int) -> some View {
        Button(action: {
            if item.submenu.isEmpty {
                ContextMenuPresenter.performAction(item.action, in: session)
            } else if let window {
                ContextMenuPresenter.presentSubmenu(
                    items: item.submenu,
                    from: window,
                    parentLevel: level,
                    rowIndex: index,
                    in: session
                )
            }
        }) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundColor(item.role == .destructive ? destructiveTextColor : primaryTextColor)
                Spacer()
                if !item.submenu.isEmpty {
                    Text(">")
                        .font(.system(size: 13))
                        .foregroundColor(primaryTextColor.opacity(0.74))
                }
            }
            .frame(width: rowWidth, height: ContextMenuMetrics.rowHeight)
            .padding(.horizontal, 12)
        }
        .buttonStyle(ContextMenuButtonStyle(role: item.role))
        .onHover { isHovered in
            guard isHovered else { return }

            if item.submenu.isEmpty {
                ContextMenuPresenter.closeSubmenus(from: level + 1, in: session)
            } else if let window {
                ContextMenuPresenter.presentSubmenu(
                    items: item.submenu,
                    from: window,
                    parentLevel: level,
                    rowIndex: index,
                    in: session
                )
            }
        }
    }

    private var rowWidth: Float {
        max(156, min(296, Float((items.map(\.title.count).max() ?? 0) * 8 + 16)))
    }
}

private struct ContextMenuButtonStyle: ButtonStyle {
    let role: ContextMenuPresentation.Item.Role?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangleShape(cornerRadius: 5).fill(
                    configuration.isHighlighted ? highlightColor : Color.clear
                )
            )
    }
}

private let backgroundColor = Color.black.opacity(0.3 as Float)
private let highlightColor = Color(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
private let primaryTextColor = Color(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
private let destructiveTextColor = Color(red: 1.0, green: 0.36, blue: 0.36, alpha: 1)
