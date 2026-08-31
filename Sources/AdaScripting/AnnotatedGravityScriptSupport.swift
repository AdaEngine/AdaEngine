@_spi(Scripting) import AdaECS
import Gravity

@GSExportable("AdaSystemContext")
final class AnnotatedGravitySystemContext: @unchecked Sendable {
    let deltaTime: Double

    init(deltaTime: Double) {
        self.deltaTime = deltaTime
    }
}

final class AnnotatedGravityRuntimeDelegate: GravityVirtualMachineDelegate, @unchecked Sendable {
    private(set) var errors: [String] = []
    private let pathsByFileID: [UInt32: String]
    private let sourcesByPath: [String: ResolvedGravityScriptModule.Source]

    init(module: ResolvedGravityScriptModule) {
        self.pathsByFileID = module.pathsByFileID
        self.sourcesByPath = module.sourcesByPath
    }

    func append(_ message: String) { errors.append(message) }

    func virtualMachineLoadFile(
        _ virtualMachine: GravityVirtualMachine,
        file: String,
        fileId: inout UInt32,
        isStatic: inout Bool
    ) -> String? {
        guard let source = sourcesByPath[file] else {
            return nil
        }
        fileId = source.fileID
        isStatic = true
        return source.source
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didErrorWith message: String,
        errorType: error_type_t,
        errorDescription: error_desc_t
    ) {
        if let path = pathsByFileID[errorDescription.fileid] {
            errors.append("\(path):\(errorDescription.lineno):\(errorDescription.colno): \(message)")
        } else {
            errors.append(message)
        }
    }

    func virtualMachineDidReciveLog(_ virtualMachine: GravityVirtualMachine, message: String) {}
    func virtualMachineDidClearLog(_ virtualMachine: GravityVirtualMachine) {}
    func virtualMachineBridgeEquals(_ virtualMachine: GravityVirtualMachine, lhsValue: GSValue, rhsValue: GSValue) -> Bool { false }
    func virtualMachine(_ virtualMachine: GravityVirtualMachine, didExecuteIn ctx: GSValue, arguments: [GSValue], argumentsCount: Int16, vIndex: UInt32) -> Bool { false }
    func virtualMachine(_ virtualMachine: GravityVirtualMachine, didSetValue value: GSValue, in target: GSValue, forKey key: String) -> Bool { false }
    func virtualMachine(_ virtualMachine: GravityVirtualMachine, didGetValueFrom target: GSValue, forKey key: String) throws -> GSValue? { nil }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didSetUndefValue value: GSValue,
        in target: GSValue,
        forKey key: String
    ) -> Bool {
        guard let component = target.toObjectOf(AnnotatedGravityComponentView.self) else {
            return false
        }
        return component.set(key, value)
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didGetUndefValueFrom target: GSValue,
        forKey key: String
    ) throws -> GSValue? {
        if let row = target.toObjectOf(AnnotatedGravityQueryRow.self),
           let component = row.component(named: key) {
            return GSValue(object: component, in: virtualMachine)
        }
        if let component = target.toObjectOf(AnnotatedGravityComponentView.self) {
            return component.get(key)
        }
        return nil
    }

    func virtualMachine(_ virtualMachine: GravityVirtualMachine, didRequestStringWith length: UInt32) -> String { "" }
}

enum AnnotatedGravityValueBridge {
    static func makeGravityValue(_ value: EditorFieldValue, virtualMachine: GravityVirtualMachine) -> GSValue {
        switch value {
        case .null: GSValue(nullIn: virtualMachine)
        case .bool(let value): GSValue(boolean: value, in: virtualMachine)
        case .int(let value): GSValue(integer: value, in: virtualMachine)
        case .double(let value): GSValue(double: value, in: virtualMachine)
        case .string(let value): GSValue(string: value, in: virtualMachine)
        case .array(let values):
            GSValue(newArrayIn: virtualMachine, items: values.map { makeGravityValue($0, virtualMachine: virtualMachine) as Any })
        case .object(let values):
            GSValue(
                newArrayIn: virtualMachine,
                items: ["red", "green", "blue", "alpha"].compactMap { values[$0] }.map {
                    makeGravityValue($0, virtualMachine: virtualMachine) as Any
                }
            )
        }
    }

    static func makeEditorFieldValue(_ value: GSValue) -> EditorFieldValue? {
        if value.isNull || value.isUndefined {
            return .null
        }
        if value.isBool {
            return .bool(value.toBoolean)
        }
        if value.isInteger {
            guard let integer = Int(exactly: value.toInteger) else {
                return nil
            }
            return .int(integer)
        }
        if value.isDouble {
            return .double(value.toDouble)
        }
        if value.isString {
            return .string(value.toString)
        }
        if value.isList {
            var result: [EditorFieldValue] = []
            for item in value.toList {
                guard let converted = makeEditorFieldValue(item) else {
                    return nil
                }
                result.append(converted)
            }
            return .array(result)
        }
        return nil
    }
}

extension GravityAnnotation {
    func stringArgument(label: String) -> String? {
        arguments.first { $0.label == label }?.value.stringValue
    }

    func identifierListArgument(label: String) -> [String] {
        guard let value = arguments.first(where: { $0.label == label })?.value else {
            return []
        }
        switch value {
        case .identifier(let value):
            return [value]
        case .list(let values):
            return values.compactMap(\.identifierValue)
        default:
            return []
        }
    }
}

extension GravityAnnotation.Value {
    var identifierValue: String? {
        guard case .identifier(let value) = self else {
            return nil
        }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }
        return value
    }
}
