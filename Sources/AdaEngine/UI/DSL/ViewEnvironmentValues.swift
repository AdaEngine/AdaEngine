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
    var font: Font? {
        get {
            self[FontViewEnvironmentKey.self]
        }
        set {
            self[FontViewEnvironmentKey.self] = newValue
        }
    }

    var foregroundColor: Color? {
        get {
            self[ForegroundColorEnvironmentKey.self]
        }
        set {
            self[ForegroundColorEnvironmentKey.self] = newValue
        }
    }

    var scaleFactor: Float {
        get {
            return self[ScaleFactorEnvironmentKey.self] ?? 1
        }
        set {
            self[ScaleFactorEnvironmentKey.self] = newValue
        }
    }
}
