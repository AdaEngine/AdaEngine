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
    }
}

@MainActor
private enum ContextMenuPresenter {
    static func present(_ presentation: ContextMenuPresentation, in app: AppWorlds) {
        guard !presentation.items.isEmpty else { return }

        let size = menuSize(for: presentation)
        let origin = menuOrigin(for: presentation, menuSize: size)
        let window = UIWindow(
            configuration: UIWindow.Configuration(
                title: "",
                frame: Rect(origin: origin, size: size),
                minimumSize: size,
                chrome: .borderless,
                background: .transparent,
                level: .floating,
                collectionBehavior: .allSpacesStationary,
                makeKey: true
            )
        )

        let container = UIContainerView(
            rootView: ContextMenuWindowContent(
                presentation: presentation,
                close: { [weak window] in
                    window?.close()
                }
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
        window.showWindow(makeFocused: true)
    }

    private static func menuSize(for presentation: ContextMenuPresentation) -> Size {
        let longestTitleCount = presentation.items.map(\.title.count).max() ?? 0
        let width = max(180, min(320, Float(longestTitleCount * 8 + 40)))
        let height = Float(presentation.items.count) * ContextMenuMetrics.rowHeight + ContextMenuMetrics.verticalPadding * 2
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
}

private enum ContextMenuMetrics {
    static let rowHeight: Float = 32
    static let verticalPadding: Float = 6
}

private struct ContextMenuWindowContent: View {
    let presentation: ContextMenuPresentation
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(presentation.items) { item in
                Button(action: {
                    close()
                    item.action?()
                }) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 13))
                            .foregroundColor(item.role == .destructive ? destructiveTextColor : primaryTextColor)
                        Spacer()
                    }
                    .frame(width: rowWidth, height: ContextMenuMetrics.rowHeight)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(ContextMenuButtonStyle(role: item.role))
            }
        }
        .padding(.vertical, ContextMenuMetrics.verticalPadding)
        .frame(width: rowWidth + 24)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(backgroundColor))
    }

    private var rowWidth: Float {
        max(156, min(296, Float((presentation.items.map(\.title.count).max() ?? 0) * 8 + 16)))
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

private let backgroundColor = Color(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.97)
private let highlightColor = Color(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
private let primaryTextColor = Color(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
private let destructiveTextColor = Color(red: 1.0, green: 0.36, blue: 0.36, alpha: 1)
