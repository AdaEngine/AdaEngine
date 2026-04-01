//
//  Theme.swift
//  AdaEngine
//

/// A key for accessing typed values stored in a ``Theme``.
///
/// Define a new theme key by conforming to this protocol and specifying a default value:
///
/// ```swift
/// struct MyColorsKey: ThemeKey {
///     static let defaultValue = MyColors()
/// }
/// ```
///
/// Then extend ``Theme`` with a convenience accessor:
///
/// ```swift
/// extension Theme {
///     var myColors: MyColors {
///         get { self[MyColorsKey.self] }
///         set { self[MyColorsKey.self] = newValue }
///     }
/// }
/// ```
public protocol ThemeKey {
    associatedtype Value: Sendable
    static var defaultValue: Value { get }
}

/// A type-safe container of design tokens that can be injected into the view hierarchy via the environment.
///
/// `Theme` is a keyed store, analogous to ``EnvironmentValues``, but dedicated to visual design.
/// A single theme instance groups colors, typography, spacing, and any other design tokens you need.
///
/// ## Usage
///
/// Apply a theme to a view tree:
///
/// ```swift
/// ContentView()
///     .theme(myTheme)
/// ```
///
/// Read the theme inside any view:
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.theme) var theme
///
///     var body: some View {
///         Text("Hello")
///             .foregroundColor(theme[MyColorsKey.self].primary)
///     }
/// }
/// ```
public struct Theme: Sendable {

    private var values: [ObjectIdentifier: any Sendable] = [:]

    public init() {}

    /// Accesses the value associated with a custom theme key.
    public subscript<K: ThemeKey>(_ key: K.Type) -> K.Value {
        get { (values[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }

    /// Merges another theme into this one. Values from `other` take precedence.
    public mutating func merge(_ other: Theme) {
        values.merge(other.values, uniquingKeysWith: { $1 })
    }
}
