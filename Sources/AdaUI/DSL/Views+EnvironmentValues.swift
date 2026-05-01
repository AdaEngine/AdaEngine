//
//  EnvironmentValues.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import AdaApp
import AdaText
import AdaUtils

public extension EnvironmentValues {
    /// The default font of this environment.
    @Entry var font: Font?

    /// The default foreground color of this environment.
    @Entry var foregroundColor: Color?

    /// Current scale factor of the screen.
    @Entry var scaleFactor: Float = Screen.main?.scale ?? 1

    /// The maximum number of lines that text can occupy in a view.
    @Entry var lineLimit: Int?

    /// The line break mode that text uses when it reaches the available width.
    @Entry var lineBreakMode: LineBreakMode = .byWordWrapping

    /// The alignment of wrapped text lines.
    @Entry var multilineTextAlignment: TextAlignment = .center

    /// Returns accent color of the system.
    @Entry var accentColor: Color = Color.accentColor

    /// The safe area insets of the nearest container or screen.
    @Entry var safeAreaInsets: EdgeInsets = EdgeInsets()

    /// Insets reserved by platform window chrome that overlays app content.
    @Entry internal var navigationBarChromeInsets: EdgeInsets = EdgeInsets()
}

public extension View {
    /// Apply accent color to all child views.
    func accentColor(_ color: Color) -> some View {
        self.environment(\.accentColor, color)
    }
}

@_spi(AdaEngine)
public extension EnvironmentValues {
    @Entry var debugViewDrawingOptions: _DebugViewDrawingOptions = []
}
