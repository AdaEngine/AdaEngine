public enum AdaScriptSchemaParser {
    public static func parse(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptDataSchema] {
        var schemas: [AdaScriptDataSchema] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            schemas += try parser.parse().schemas
        }

        var ids = Set<String>()
        var names = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateID(schema.id)
            }
            guard names.insert(schema.name).inserted else {
                throw AdaScriptSchemaError.duplicateName(schema.name)
            }
        }
        return schemas
    }

    public static func parseResourceBindings(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptResourceBinding] {
        var bindings: [AdaScriptResourceBinding] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            bindings += try parser.parse().resourceBindings
        }
        return bindings
    }

    public static func parseScriptables(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptableSchema] {
        var schemas: [AdaScriptableSchema] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            schemas += try parser.parse().scriptables
        }

        var ids = Set<String>()
        var names = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateID(schema.id)
            }
            guard names.insert(schema.name).inserted else {
                throw AdaScriptSchemaError.duplicateName(schema.name)
            }
        }
        return schemas
    }

    public static func parseSystemCapabilities(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptSystemCapabilities] {
        var capabilities: [AdaScriptSystemCapabilities] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            capabilities += try parser.parse().systemCapabilities
        }
        return capabilities
    }

    public static func parseViews(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptViewSchema] {
        var schemas: [AdaScriptViewSchema] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            schemas += try parser.parse().views
        }

        var ids = Set<String>()
        var names = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateID(schema.id)
            }
            guard names.insert(schema.className).inserted else {
                throw AdaScriptSchemaError.duplicateName(schema.className)
            }
        }
        return schemas
    }
}
