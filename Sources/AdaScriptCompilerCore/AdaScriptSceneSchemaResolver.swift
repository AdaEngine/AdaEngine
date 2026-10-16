import CoreFoundation
import Foundation

/// A finding about how a scene's saved component data relates to the current script schema.
public struct AdaScriptSceneDataDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public enum Severity: String, Equatable, Sendable {
        /// The scene still loads; saved data was renamed, removed, or added since it was written.
        case warning
        /// The saved value cannot be represented by the current schema.
        case error
    }

    public let component: String
    public let message: String
    public let severity: Severity

    public init(component: String, message: String, severity: Severity) {
        self.component = component
        self.message = message
        self.severity = severity
    }

    public var description: String { "\(severity.rawValue): \(component): \(message)" }
}

/// Resolves scene component keys against script schemas by stable ID, current name, or alias,
/// and reports schema drift for the saved field values.
///
/// A scene should store the stable ID. Names and aliases keep older scenes loadable after a
/// rename; they resolve with a warning that tells the author to save the scene again.
public enum AdaScriptSceneSchemaResolver {
    public enum Match: Equatable, Sendable {
        case alias
        case name
        case stableID
    }

    public struct Resolution: Sendable {
        public let match: Match
        public let schema: AdaScriptDataSchema

        /// The key a scene should be saved with.
        public var canonicalKey: String { schema.id }
    }

    public static func resolve(key: String, in schemas: [AdaScriptDataSchema]) -> Resolution? {
        if let schema = schemas.first(where: { $0.id == key }) {
            return Resolution(match: .stableID, schema: schema)
        }
        if let schema = schemas.first(where: { $0.name == key }) {
            return Resolution(match: .name, schema: schema)
        }
        if let schema = schemas.first(where: { $0.aliases.contains(key) }) {
            return Resolution(match: .alias, schema: schema)
        }
        return nil
    }

    /// Compares one saved component object (`JSONSerialization` output) with its schema.
    ///
    /// - Parameter reportsMissingFields: Pass `false` to skip the note for schema fields the saved
    ///   data predates; interactive loaders do, since every added field would warn until re-saved.
    public static func diagnose(
        key: String,
        fields object: [String: Any],
        schemas: [AdaScriptDataSchema],
        reportsMissingFields: Bool = true
    ) -> [AdaScriptSceneDataDiagnostic] {
        guard let resolution = resolve(key: key, in: schemas) else {
            return [AdaScriptSceneDataDiagnostic(
                component: key,
                message: "no script component has this stable ID, name, or alias; its data is not loaded",
                severity: .error
            )]
        }
        let schema = resolution.schema
        var diagnostics: [AdaScriptSceneDataDiagnostic] = []
        switch resolution.match {
        case .stableID:
            break
        case .name, .alias:
            diagnostics.append(AdaScriptSceneDataDiagnostic(
                component: schema.name,
                message: "scene refers to '\(key)'; save the scene to store the stable ID '\(schema.id)'",
                severity: .warning
            ))
        }
        let declared = Dictionary(uniqueKeysWithValues: schema.fields.map { ($0.name, $0.defaultValue) })
        for name in object.keys.sorted() where declared[name] == nil {
            diagnostics.append(AdaScriptSceneDataDiagnostic(
                component: schema.name,
                message: "saved field '\(name)' no longer exists; its value is ignored (removed or renamed?)",
                severity: .warning
            ))
        }
        for field in schema.fields {
            guard let saved = object[field.name] else {
                if reportsMissingFields {
                    diagnostics.append(AdaScriptSceneDataDiagnostic(
                        component: schema.name,
                        message: "field '\(field.name)' is not in the saved scene; using its default",
                        severity: .warning
                    ))
                }
                continue
            }
            if let problem = mismatch(saved, expected: field.defaultValue) {
                diagnostics.append(AdaScriptSceneDataDiagnostic(
                    component: schema.name,
                    message: "saved field '\(field.name)' \(problem)",
                    severity: .error
                ))
            }
        }
        return diagnostics
    }

    private static func mismatch(_ value: Any, expected: AdaScriptSchemaField.Value) -> String? {
        func isNumber(_ value: Any) -> Bool {
            guard let number = value as? NSNumber else { return false }
            return type(of: number) != type(of: NSNumber(value: true)) && number.doubleValue.isFinite
        }
        switch expected {
        case .bool:
            return (value as? NSNumber).map { type(of: $0) == type(of: NSNumber(value: true)) } == true ? nil : "is not a Bool"
        case .int, .entity:
            guard isNumber(value), let number = value as? NSNumber, number.doubleValue == number.doubleValue.rounded() else {
                return "is not an integer"
            }
            return nil
        case .double:
            return isNumber(value) ? nil : "is not a number"
        case .string:
            return value is String ? nil : "is not a string"
        case .asset:
            return value is String || value is NSNull ? nil : "is not an asset path"
        case let .vector(defaults):
            guard let items = value as? [Any], items.count == defaults.count, items.allSatisfy(isNumber) else {
                return "is not a list of \(defaults.count) numbers"
            }
            return nil
        case .color:
            if let items = value as? [Any], (3...4).contains(items.count), items.allSatisfy(isNumber) { return nil }
            if let object = value as? [String: Any], ["red", "green", "blue"].allSatisfy({ object[$0].map(isNumber) == true }) { return nil }
            return "is not a color (3-4 numbers, or red/green/blue/alpha)"
        case let .enumeration(type, cases, _):
            guard let name = value as? String, cases.contains(name) else {
                return "is not a case of \(type) (\(cases.joined(separator: ", ")))"
            }
            return nil
        }
    }
}
