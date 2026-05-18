@_spi(AdaEngine) import AdaEngine

struct EditorThemeColors: Hashable, Sendable {
    var background: Color
    var surface: Color
    var surfaceElevated: Color
    var border: Color
    var text: Color
    var muted: Color
    var blue: Color
    var purple: Color

    static let dark = EditorThemeColors(
        background: Color(red: 53 / 255, green: 55 / 255, blue: 60 / 255),
        surface: Color(red: 43 / 255, green: 45 / 255, blue: 48 / 255),
        surfaceElevated: Color(red: 30 / 255, green: 31 / 255, blue: 34 / 255),
        border: Color(red: 57 / 255, green: 59 / 255, blue: 64 / 255),
        text: Color(red: 223 / 255, green: 225 / 255, blue: 229 / 255),
        muted: Color(red: 111 / 255, green: 115 / 255, blue: 122 / 255),
        blue: Color(red: 53 / 255, green: 116 / 255, blue: 240 / 255),
        purple: Color(red: 177 / 255, green: 98 / 255, blue: 241 / 255)
    )
}

private struct EditorThemeColorsKey: ThemeKey {
    static let defaultValue: EditorThemeColors = .dark
}

extension Theme {
    var editorColors: EditorThemeColors {
        get { self[EditorThemeColorsKey.self] }
        set { self[EditorThemeColorsKey.self] = newValue }
    }

    static var adaEditor: Theme {
        var theme = Theme()
        theme.editorColors = .dark
        return theme
    }
}
