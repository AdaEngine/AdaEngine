//
//  WidgetEnvironmentValues.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

struct FontWidgetEnvironmentKey: WidgetEnvironmentKey {
    static var defaultValue: Font?
}

struct ForegroundColorEnvironmentKey: WidgetEnvironmentKey {
    static var defaultValue: Color = Color.black
}

public extension WidgetEnvironmentValues {
    var font: Font? {
        get {
            self[FontWidgetEnvironmentKey.self]
        }
        set {
            self[FontWidgetEnvironmentKey.self] = newValue
        }
    }

    var foregroundColor: Color {
        get {
            self[ForegroundColorEnvironmentKey.self]
        }
        set {
            self[ForegroundColorEnvironmentKey.self] = newValue
        }
    }
}
