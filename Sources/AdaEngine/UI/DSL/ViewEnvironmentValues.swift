//
//  ViewEnvironmentValues.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

struct FontViewEnvironmentKey: ViewEnvironmentKey {
    static var defaultValue: Font?
}

struct ForegroundColorEnvironmentKey: ViewEnvironmentKey {
    static var defaultValue: Color?
}

struct ScaleFactorEnvironmentKey: ViewEnvironmentKey {
    static var defaultValue: Float? = Screen.main?.scale
}

public extension ViewEnvironmentValues {
    /// The default font of this environment.
    var font: Font? {
        get {
            self[FontViewEnvironmentKey.self]
        }
        set {
            self[FontViewEnvironmentKey.self] = newValue
        }
    }

    /// The default foreground color of this environment.
    var foregroundColor: Color? {
        get {
            self[ForegroundColorEnvironmentKey.self]
        }
        set {
            self[ForegroundColorEnvironmentKey.self] = newValue
        }
    }

    /// Current scale factor of the screen.
    var scaleFactor: Float {
        get {
            return self[ScaleFactorEnvironmentKey.self] ?? 1
        }
        set {
            self[ScaleFactorEnvironmentKey.self] = newValue
        }
    }
}
