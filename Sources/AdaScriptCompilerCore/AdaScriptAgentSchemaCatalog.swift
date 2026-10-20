import Foundation

/// Source-defined authoring schemas from the production parser, available even
/// when the current scene or another part of the game cannot load.
public enum AdaScriptAgentSchemaCatalog {
    public static func encoded(sources: [AdaScriptCompilerSource]) throws -> Data {
        let schemas = try AdaScriptSchemaParser.parse(sources: sources)
        let values = schemas.map { schema -> [String: Any] in
            let isComponent: Bool
            switch schema.kind { case .component: isComponent = true; case .resource: isComponent = false }
            let fields = schema.fields.map(field)
            return [
                "typeName": schema.id, "name": schema.name, "aliases": schema.aliases,
                "source": schema.sourcePath, "kind": isComponent ? "component" : "resource",
                "fields": fields.map(\.description), "requiredComponents": [String](),
                "defaultPayload": Dictionary(uniqueKeysWithValues: zip(schema.fields.map(\.name), fields.map(\.defaultValue))),
            ]
        }
        return try JSONSerialization.data(withJSONObject: ["schemas": values, "validation": "production schema parser; full compilation and runtime validation are separate"], options: [.sortedKeys])
    }

    private static func field(_ field: AdaScriptSchemaField) -> (description: [String: Any], defaultValue: Any) {
        var kind: String
        var value: Any
        var extra: [String: Any] = [:]
        switch field.defaultValue {
        case let .bool(initial): kind = "bool"; value = initial
        case let .double(initial): kind = "float"; value = initial
        case let .int(initial):
            kind = "int"
            value = initial > 9_007_199_254_740_991 || initial < -9_007_199_254_740_991 ? String(initial) : initial as Any
            extra["integerEncoding"] = "decimal strings outside the JavaScript safe integer range"
        case let .string(initial): kind = "string"; value = initial
        case let .vector(initial): kind = "vector\(initial.count)"; value = initial
        case let .color(initial): kind = "color"; value = initial
        case let .enumeration(type, cases, selected):
            kind = "enumeration"; value = selected
            extra["enumType"] = type; extra["cases"] = cases
        case .entity: kind = "entityReference"; value = -1
        case let .asset(path): kind = "assetReference"; value = path.map { $0 as Any } ?? NSNull()
        }
        return (extra.merging(["name": field.name, "path": [field.name], "kind": kind, "coding": "standard", "editable": true, "defaultValue": value]) { _, new in new }, value)
    }
}
