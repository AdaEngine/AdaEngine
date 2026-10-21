import AdaECS
import AdaRender
import Gravity

/// The VM coordinator serializes this borrowed callback capability. The material
/// itself synchronizes values shared with render extraction.
@GSExportable("AdaGraphMaterial") final class AdaScriptShaderGraphBridge: @unchecked Sendable, AdaScriptNonSendableBridge {
    private let handle: ShaderGraphScriptHandle
    private let virtualMachine: GravityVirtualMachine
    private let reportDiagnostic: @Sendable (String) -> Void

    @GSExportableIgnore static func make(handle: ShaderGraphScriptHandle, virtualMachine: GravityVirtualMachine, reportDiagnostic: @escaping @Sendable (String) -> Void)
        -> AdaScriptShaderGraphBridge {
        AdaScriptShaderGraphBridge(handle: handle, virtualMachine: virtualMachine, reportDiagnostic: reportDiagnostic)
    }

    private init(handle: ShaderGraphScriptHandle, virtualMachine: GravityVirtualMachine, reportDiagnostic: @escaping @Sendable (String) -> Void) {
        self.handle = handle
        self.virtualMachine = virtualMachine
        self.reportDiagnostic = reportDiagnostic
    }

    func parameterIDs() -> GSValue {
        do { return AnnotatedGravityValueBridge.makeGravityValue(.array(try handle.ids().map { .string($0) }), virtualMachine: virtualMachine) } catch {
            report(error)
            return GSValue(nullIn: virtualMachine)
        }
    }
    func parameterName(_ id: String) -> String {
        do { return try handle.name(id) } catch {
            report(error)
            return ""
        }
    }
    func parameterType(_ id: String) -> String {
        do { return try handle.type(id).rawValue } catch {
            report(error)
            return ""
        }
    }
    func getValue(_ id: String, _ kind: String) -> GSValue {
        do {
            guard let type = ShaderGraph.ValueType(rawValue: kind) else { throw ShaderGraphScriptError.typeMismatch }
            return AnnotatedGravityValueBridge.makeGravityValue(try handle.reflected(id, type: type), virtualMachine: virtualMachine)
        } catch {
            report(error)
            return GSValue(nullIn: virtualMachine)
        }
    }
    func setValue(_ id: String, _ kind: String, _ value: GSValue) -> Bool {
        do {
            guard let type = ShaderGraph.ValueType(rawValue: kind), let reflected = AnnotatedGravityValueBridge.makeReflectedFieldValue(value) else {
                throw ShaderGraphScriptError.typeMismatch
            }
            try handle.setReflected(id, type: type, value: reflected)
            return true
        } catch {
            report(error)
            return false
        }
    }
    func getFloat(_ id: String) -> GSValue { getValue(id, "float") }
    func setFloat(_ id: String, _ value: GSValue) -> Bool { setValue(id, "float", value) }
    func getBool(_ id: String) -> GSValue { getValue(id, "bool") }
    func setBool(_ id: String, _ value: GSValue) -> Bool { setValue(id, "bool", value) }
    func getVector2(_ id: String) -> GSValue { getValue(id, "vector2") }
    func setVector2(_ id: String, _ value: GSValue) -> Bool { setValue(id, "vector2", value) }
    func getVector3(_ id: String) -> GSValue { getValue(id, "vector3") }
    func setVector3(_ id: String, _ value: GSValue) -> Bool { setValue(id, "vector3", value) }
    func getVector4(_ id: String) -> GSValue { getValue(id, "vector4") }
    func setVector4(_ id: String, _ value: GSValue) -> Bool { setValue(id, "vector4", value) }
    func getColor(_ id: String) -> GSValue { getValue(id, "color") }
    func setColor(_ id: String, _ value: GSValue) -> Bool { setValue(id, "color", value) }
    func getTexture(_ id: String) -> GSValue { getValue(id, "texture2D") }
    func setTexture(_ id: String, _ value: GSValue) -> Bool { setValue(id, "texture2D", value) }

    @GSExportableIgnore private func report(_ error: any Error) { reportDiagnostic("ShaderGraph: \(error)") }
}
