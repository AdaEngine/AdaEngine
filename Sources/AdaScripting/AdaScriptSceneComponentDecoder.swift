@_spi(Scripting) import AdaECS
import CoreFoundation
import Foundation

/// Decodes one saved scene component into a runtime payload, validating each field against its
/// reflected kind so a scene can never place invalid data in a component.
enum AdaScriptSceneComponentDecoder {
    static func decode(_ object: [String: Any], as descriptor: RuntimeComponentDescriptor) throws -> RuntimeComponentPayload {
        var payload = descriptor.makeDefault()
        for field in descriptor.fields {
            guard let saved = object[field.key] else {
                continue
            }
            guard
                let value = value(saved, kind: field.kind),
                let updated = field.write(payload, value) as? RuntimeComponentPayload
            else {
                throw AdaScriptError.invalidManifest("Invalid value for '\(descriptor.name).\(field.key)' in scene component")
            }
            payload = updated
        }
        return payload
    }

    static func value(_ json: Any, kind: ReflectedFieldKind) -> ReflectedFieldValue? {
        func number(_ value: Any) -> Double? {
            guard let number = value as? NSNumber, type(of: number) != type(of: NSNumber(value: true)) else { return nil }
            return number.doubleValue
        }
        switch kind {
        case .bool:
            return (json as? Bool).map(ReflectedFieldValue.bool)
        case .int:
            guard let double = number(json), double == double.rounded(), let int = Int(exactly: double) else { return nil }
            return .int(int)
        case .float:
            return number(json).map(ReflectedFieldValue.double)
        case .string, .enumeration:
            return (json as? String).map(ReflectedFieldValue.string)
        case .vector2, .vector3, .vector4:
            guard let items = json as? [Any] else { return nil }
            let numbers = items.compactMap(number)
            return numbers.count == items.count ? .array(numbers.map(ReflectedFieldValue.double)) : nil
        case .color:
            if let items = json as? [Any] {
                let numbers = items.compactMap(number)
                return numbers.count == items.count ? .array(numbers.map(ReflectedFieldValue.double)) : nil
            }
            guard let object = json as? [String: Any] else { return nil }
            var channels: [String: ReflectedFieldValue] = [:]
            for (name, raw) in object {
                guard let double = number(raw) else { return nil }
                channels[name] = .double(double)
            }
            return .object(channels)
        case .assetReference:
            if json is NSNull { return .null }
            return (json as? String).map(ReflectedFieldValue.string)
        case .readOnly:
            return nil
        }
    }
}
