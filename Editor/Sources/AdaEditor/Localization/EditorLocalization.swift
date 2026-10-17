import Foundation
import Observation

enum EditorLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case russian = "ru"

    var title: String {
        switch self {
        case .system: "System language"
        case .english: "English"
        case .russian: "Русский"
        }
    }

    static func resolve(_ preference: Self, preferredLanguages: [String]) -> Self {
        guard preference == .system else { return preference }
        for identifier in preferredLanguages {
            switch identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first {
            case "ru": return .russian
            case "en": return .english
            default: continue
            }
        }
        return .english
    }
}

/// App-owned preferences; game documents and user content keep their original text.
@Observable
@MainActor
final class EditorLocalization {
    static let shared = EditorLocalization()
    static let preferenceKey = "AdaEditor.language"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let preferredLanguages: [String]
    var preference: EditorLanguage {
        didSet { defaults.set(preference.rawValue, forKey: Self.preferenceKey) }
    }

    var language: EditorLanguage {
        EditorLanguage.resolve(preference, preferredLanguages: preferredLanguages)
    }

    init(defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        self.preference = defaults.string(forKey: Self.preferenceKey).flatMap(EditorLanguage.init(rawValue:)) ?? .system
    }
}

/// Explicit UI lookups also support values supplied by settings/inspector models.
@MainActor
enum L10n {
    static func tr(_ key: String) -> String {
        catalog.string(key, language: EditorLocalization.shared.language)
    }

    static func text(_ message: EditorLocalizedMessage) -> String {
        catalog.string(message.key, language: EditorLocalization.shared.language, arguments: message.arguments)
    }

    static func matches(_ query: String, keys: [String]) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace)
        let searchable = (keys + keys.map(tr)).joined(separator: " ")
        return terms.allSatisfy { searchable.localizedCaseInsensitiveContains(String($0)) }
    }

    static let catalog = EditorTranslationCatalog(bundle: .editor)
}

/// Interpolation keeps file names, model identifiers and user content out of translation keys.
struct EditorLocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
    let key: String
    let arguments: [String]

    init(stringLiteral value: String) {
        key = value
        arguments = []
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
            arguments.reserveCapacity(interpolationCount)
        }

        mutating func appendLiteral(_ literal: String) { key += literal }

        mutating func appendInterpolation<Value>(_ value: Value) {
            key += "{\(arguments.count)}"
            arguments.append(String(describing: value))
        }
    }
}

struct EditorTranslationCatalog: Sendable {
    let english: [String: String]
    let russian: [String: String]

    init(bundle: Bundle) {
        func load(_ language: String) -> [String: String] {
            guard let url = bundle.url(forResource: language, withExtension: "json", subdirectory: "Assets/Localization"),
                  let data = try? Data(contentsOf: url),
                  let strings = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return strings
        }
        english = load("en")
        russian = load("ru")
    }

    func string(_ key: String, language: EditorLanguage, arguments: [String] = []) -> String {
        let template = (language == .russian ? russian[key] : english[key]) ?? english[key] ?? key
        // Expand only placeholders in the template, never placeholders inside user values.
        var result = ""
        var cursor = template.startIndex
        while cursor < template.endIndex {
            if template[cursor] == "{", let end = template[cursor...].firstIndex(of: "}"),
               let index = Int(template[template.index(after: cursor)..<end]), arguments.indices.contains(index) {
                result += arguments[index]
                cursor = template.index(after: end)
            } else {
                result.append(template[cursor])
                cursor = template.index(after: cursor)
            }
        }
        return result
    }
}
