#if canImport(GravityAOT)
    import AdaRender
    import AdaUtils
    import GravityAOT

    final class NativeShaderGraphHost: NativeHostObject {
        private let handle: ShaderGraphScriptHandle
        init(handle: ShaderGraphScriptHandle) { self.handle = handle }

        func call(_ method: String, arguments: [NativeValue]) throws -> NativeValue? {
            do {
                if method == "parameterIDs", arguments.isEmpty {
                    return .list(try handle.ids().map { .string($0) })
                }
                guard let first = arguments.first, case .string(let id) = first else { throw ShaderGraphScriptError.typeMismatch }
                if method == "parameterName", arguments.count == 1 {
                    return .string(try handle.name(id))
                }
                if method == "parameterType", arguments.count == 1 {
                    return .string(try handle.type(id).rawValue)
                }
                let types: [String: ShaderGraph.ValueType] = [
                    "Float": .float, "Bool": .bool, "Vector2": .vector2, "Vector3": .vector3, "Vector4": .vector4, "Color": .color, "Texture": .texture2D,
                ]
                let type: ShaderGraph.ValueType
                let rawValue: NativeValue?
                if method == "getValue" || method == "setValue" {
                    guard arguments.count == (method == "getValue" ? 2 : 3) else { throw ShaderGraphScriptError.typeMismatch }
                    guard arguments.count >= 2, case .string(let kind) = arguments[1], let parsed = ShaderGraph.ValueType(rawValue: kind) else { throw ShaderGraphScriptError.typeMismatch }
                    type = parsed
                    rawValue = arguments.count == 3 ? arguments[2] : nil
                } else {
                    guard method.hasPrefix("get") || method.hasPrefix("set"), let parsed = types[String(method.dropFirst(3))] else {
                        return nil
                    }
                    guard arguments.count == (method.hasPrefix("get") ? 1 : 2) else { throw ShaderGraphScriptError.typeMismatch }
                    type = parsed
                    rawValue = arguments.count == 2 ? arguments[1] : nil
                }
                if method.hasPrefix("get") {
                    return try handle.reflected(id, type: type).nativeValue
                }
                guard let reflected = rawValue?.literal?.reflected else { throw ShaderGraphScriptError.typeMismatch }
                try handle.setReflected(id, type: type, value: reflected)
                return .boolean(true)
            } catch {
                RuntimeLogStore.shared.append(level: "error", label: "AdaScript", message: "ShaderGraph: \(error)")
                return method.hasPrefix("set") ? .boolean(false) : .null
            }
        }
    }
#endif
