@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
import Gravity

struct AdaScriptLinkedComponentConstructor: Sendable {
    let constructor: RegisteredRuntimeComponentConstructor
    let index: Int

}

enum AdaScriptComponentRuntime {
    static func runtimeDescriptors(
        schemas: [AdaScriptDataSchema]
    ) -> [RuntimeComponentDescriptor] {
        schemas.compactMap { schema in
            guard schema.kind == .component else { return nil }
            return RuntimeComponentDescriptor(
                stableID: schema.id,
                name: schema.name,
                aliases: schema.aliases,
                fieldNames: schema.fields.map(\.name),
                fieldKinds: schema.fields.map { $0.defaultValue.reflectedKind },
                defaultValues: schema.fields.map { $0.defaultValue.reflectedDefault }
            )
        }
    }

    static func linkedConstructors() -> [AdaScriptLinkedComponentConstructor] {
        RuntimeTypeRegistry.registeredRuntimeComponentConstructors()
            .enumerated()
            .map { AdaScriptLinkedComponentConstructor(constructor: $0.element, index: $0.offset) }
    }

    static func prelude(
        constructors: [AdaScriptLinkedComponentConstructor],
        authoredSource: String = ""
    ) -> String {
        let constructorDeclarations = constructors.compactMap { linkedConstructor -> String? in
            let constructor = linkedConstructor.constructor
            guard
                isIdentifier(constructor.name),
                constructor.parameters.allSatisfy({ isIdentifier($0.name) })
            else {
                return nil
            }
            let parameters = constructor.parameters
                .map(\.name)
                .joined(separator: ", ")
            let arguments = constructor.parameters
                .map(\.name)
                .joined(separator: ", ")
            return """
            func \(constructor.name)(\(parameters)) {
                return __adaComponentFactory.make(\(linkedConstructor.index), [\(arguments)]);
            }
            """
        }
        return ([
            "extern var __adaComponentFactory;",
            AdaScriptSpriteLayoutLibrary.source,
            """
            class __AdaVector3Factory {
                var ZERO {
                    get { return [0.0, 0.0, 0.0]; }
                };

                func exec(x, y, z) {
                    return [x, y, z];
                }
            }
            var Vector3 = __AdaVector3Factory();
            """,
        ] + structuredFactories(authoredSource: authoredSource) + constructorDeclarations).joined(separator: "\n") + "\n"
    }

    /// Constructors for the structured schema field types. Each is emitted only when the module
    /// uses it and does not declare a symbol of the same name, so existing scripts keep working.
    private static func structuredFactories(authoredSource: String) -> [String] {
        let factories: [(name: String, source: String)] = [
            ("Vector2", """
            class __AdaVector2Factory {
                var ZERO { get { return [0.0, 0.0]; } };
                func exec(x, y) { return [x, y]; }
            }
            var Vector2 = __AdaVector2Factory();
            """),
            ("Vector4", """
            class __AdaVector4Factory {
                var ZERO { get { return [0.0, 0.0, 0.0, 0.0]; } };
                func exec(x, y, z, w) { return [x, y, z, w]; }
            }
            var Vector4 = __AdaVector4Factory();
            """),
            ("Color", """
            class __AdaColorFactory {
                var white { get { return [1.0, 1.0, 1.0, 1.0]; } };
                var black { get { return [0.0, 0.0, 0.0, 1.0]; } };
                var clear { get { return [0.0, 0.0, 0.0, 0.0]; } };
                func exec(r, g, b, a = 1.0) { return [r, g, b, a]; }
            }
            var Color = __AdaColorFactory();
            """),
        ]
        return factories.compactMap { factory in
            let usesFactory = authoredSource.contains("\(factory.name)(") || authoredSource.contains("\(factory.name).")
            let declaresName = ["class", "struct", "enum", "var", "func"].contains { authoredSource.contains("\($0) \(factory.name)") }
            return usesFactory && !declaresName ? factory.source : nil
        }
    }

    static func bind(
        to virtualMachine: GravityVirtualMachine,
        constructors: [AdaScriptLinkedComponentConstructor],
        runtimeDescriptors: [RuntimeComponentDescriptor] = [],
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) throws {
        try virtualMachine.bindClass(with: AnnotatedGravityComponentValue.self)
        try virtualMachine.bindClass(with: AnnotatedGravityComponentFactory.self)
        virtualMachine.setValue(
            AnnotatedGravityComponentFactory.make(
                constructors: constructors.map(\.constructor),
                runtimeDescriptors: runtimeDescriptors,
                reportDiagnostic: reportDiagnostic
            ),
            forKey: "__adaComponentFactory"
        )
    }

    private static func isIdentifier(_ value: String) -> Bool {
        guard let first = value.first, first == "_" || first.isLetter else {
            return false
        }
        return value.dropFirst().allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }
}

@GSExportable("AdaComponentValue")
final class AnnotatedGravityComponentValue: @unchecked Sendable {
    @GSExportableIgnore
    private var component: (any Component)?

    @GSExportableIgnore
    init(component: consuming any Component) {
        self.component = component
    }

    @GSExportableIgnore
    init() {
        self.component = nil
    }

    @GSExportableIgnore
    func takeComponent() -> (any Component)? {
        let component = component
        self.component = nil
        return component
    }
}

@GSExportable("AdaComponentFactory")
final class AnnotatedGravityComponentFactory: @unchecked Sendable {
    @GSExportableIgnore
    private let constructors: [RegisteredRuntimeComponentConstructor]

    @GSExportableIgnore
    private let constructorsByName: [String: RegisteredRuntimeComponentConstructor]

    @GSExportableIgnore
    private let runtimeDescriptorsByName: [String: RuntimeComponentDescriptor]

    @GSExportableIgnore
    private let reportDiagnostic: @Sendable (String) -> Void

    @GSExportableIgnore
    static func make(
        constructors: [RegisteredRuntimeComponentConstructor],
        runtimeDescriptors: [RuntimeComponentDescriptor],
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) -> AnnotatedGravityComponentFactory {
        AnnotatedGravityComponentFactory(
            constructors: constructors,
            runtimeDescriptors: runtimeDescriptors,
            reportDiagnostic: reportDiagnostic
        )
    }

    private init(
        constructors: [RegisteredRuntimeComponentConstructor],
        runtimeDescriptors: borrowing [RuntimeComponentDescriptor],
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        self.constructors = constructors
        self.constructorsByName = Dictionary(uniqueKeysWithValues: constructors.map { ($0.name, $0) })
        self.runtimeDescriptorsByName = Dictionary(
            uniqueKeysWithValues: runtimeDescriptors.flatMap { descriptor in
                [(descriptor.name, descriptor), (descriptor.stableID, descriptor)]
            }
        )
        self.reportDiagnostic = reportDiagnostic
    }

    func make(_ constructorIndex: Int, _ argumentValues: GSValue) -> AnnotatedGravityComponentValue {
        guard constructors.indices.contains(constructorIndex) else {
            reportDiagnostic("AdaScript component constructor index \(constructorIndex) is not linked")
            return AnnotatedGravityComponentValue()
        }
        guard let arguments = arguments(from: argumentValues) else { return AnnotatedGravityComponentValue() }

        do {
            return AnnotatedGravityComponentValue(
                component: try constructors[constructorIndex].construct(arguments: arguments)
            )
        } catch {
            reportDiagnostic(String(describing: error))
            return AnnotatedGravityComponentValue()
        }
    }

    func makeNamed(_ name: String, _ argumentValues: GSValue) -> AnnotatedGravityComponentValue {
        guard let arguments = arguments(from: argumentValues) else { return AnnotatedGravityComponentValue() }
        if let constructor = constructorsByName[name] {
            do {
                return AnnotatedGravityComponentValue(component: try constructor.construct(arguments: arguments))
            } catch {
                reportDiagnostic(String(describing: error))
                return AnnotatedGravityComponentValue()
            }
        }
        guard let descriptor = runtimeDescriptorsByName[name] else {
            reportDiagnostic("Unknown AdaScript component constructor '\(name)'")
            return AnnotatedGravityComponentValue()
        }
        guard arguments.count == descriptor.defaultValues.count else {
            reportDiagnostic("AdaScript component '\(name)' expected \(descriptor.defaultValues.count) arguments")
            return AnnotatedGravityComponentValue()
        }
        var values = descriptor.defaultValues
        for index in arguments.indices {
            if let value = arguments[index] {
                guard descriptor.fields[index].accepts(value) else {
                    reportDiagnostic("AdaScript component '\(name)' received an invalid value for '\(descriptor.fields[index].key)'")
                    return AnnotatedGravityComponentValue()
                }
                values[index] = value
            }
        }
        return AnnotatedGravityComponentValue(
            component: RuntimeComponentPayload(
                componentID: descriptor.componentID,
                stableID: descriptor.stableID,
                values: values
            )
        )
    }

    private func arguments(from argumentValues: GSValue) -> [ReflectedFieldValue?]? {
        guard argumentValues.isList else {
            reportDiagnostic("AdaScript component constructor arguments must be a list")
            return nil
        }
        var arguments: [ReflectedFieldValue?] = []
        arguments.reserveCapacity(argumentValues.toList.count)
        for value in argumentValues.toList {
            if value.isNull || value.isUndefined {
                arguments.append(nil)
            } else if let fieldValue = AnnotatedGravityValueBridge.makeReflectedFieldValue(value) {
                arguments.append(fieldValue)
            } else {
                reportDiagnostic("AdaScript component constructor received an unsupported value")
                return nil
            }
        }
        return arguments
    }
}

extension AdaScriptSchemaField.Value {
    /// The editor and validation shape of a field with this default.
    var reflectedKind: ReflectedFieldKind {
        switch self {
        case .bool: .bool
        case .double: .float
        case .int: .int
        case .string: .string
        case let .vector(components): components.count == 2 ? .vector2 : components.count == 3 ? .vector3 : .vector4
        case .color: .color
        case let .enumeration(_, cases, _): .enumeration(cases)
        // Entity references are plain integer ids (-1 is "none") until the inspector gains an entity picker.
        case .entity: .int
        case .asset: .assetReference
        }
    }

    var reflectedDefault: ReflectedFieldValue {
        switch self {
        case let .bool(value): .bool(value)
        case let .double(value): .double(value)
        case let .int(value): .int(Int(value))
        case let .string(value): .string(value)
        case let .vector(components): .array(components.map(ReflectedFieldValue.double))
        case let .color(components):
            .object(Dictionary(uniqueKeysWithValues: zip(["red", "green", "blue", "alpha"], components.map(ReflectedFieldValue.double))))
        case let .enumeration(_, _, selected): .string(selected)
        case .entity: .int(-1)
        case let .asset(path): path.map(ReflectedFieldValue.string) ?? .null
        }
    }
}
