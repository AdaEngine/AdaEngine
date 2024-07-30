//
//  EnvironmentValues.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

public extension EnvironmentValues {
    /// The default font of this environment.
    @Entry var font: Font?

    /// The default foreground color of this environment.
    @Entry var foregroundColor: Color?

    /// Current scale factor of the screen.
    @Entry var scaleFactor: Float = Screen.main?.scale ?? 1

    /// The maximum number of lines that text can occupy in a view.
    @Entry var lineLimit: Int?
}