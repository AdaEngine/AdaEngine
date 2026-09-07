@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
import AdaUI
import AdaUtils
import Foundation
import Gravity

/// Explicit export metadata. Parameter names address stored properties on the @view class.
public struct AdaScriptUIExport: Codable, Hashable, Sendable {
    public var source: String
    public var identifier: String
    public var signature: UIDescriptorSignature

    public init(source: String, identifier: String, signature: UIDescriptorSignature) {
        self.source = source; self.identifier = identifier; self.signature = signature
    }
}

extension UICatalog {
    /// Compiles an exported AdaScript View once; each mounted node owns a separate script instance.
    @MainActor
    public func adding(script export: AdaScriptUIExport, sources: [AdaScriptSource]) throws -> Self {
        let views = try AdaScriptViewScanner.declarations(in: sources)
        guard views.contains(where: { $0.identifier == export.identifier }) else { throw UIDiagnostic("Unknown exported @view '\(export.identifier)'.") }
        let runtime = try AdaScriptViewModuleRuntime(sources: sources, views: views, exportedParameters: export.signature.parameters.map(\.name))
        let descriptor = UINativeViewDescriptor(signature: export.signature) { inputs in
            AnyView(AdaScriptExportedView(runtime: runtime, identifier: export.identifier, inputs: inputs, catalog: self))
        }
        return try adding(views: [descriptor])
    }
}

@MainActor
private struct AdaScriptExportedView: View {
    let runtime: AdaScriptViewModuleRuntime
    let identifier: String
    let inputs: UIFactoryContext
    let catalog: UICatalog
    @State private var storage: AdaScriptViewStorage?
    @State private var revision = 0

    var body: some View {
        _ = revision
        do {
            let resolved: AdaScriptViewStorage
            if let storage { resolved = storage }
            else { resolved = try runtime.makeStorage(identifier: identifier); storage = resolved }
            try resolved.updateInputs(inputs.arguments)
            try resolved.updateEnvironment(["colorScheme": .string("dark"), "isEnabled": .bool(true), "scaleFactor": .double(1), "userInterfaceIdiom": .string("desktop")])
            guard let model = resolved.model else { throw UIDiagnostic("AdaScript did not produce UI.") }
            let revision = $revision
            return AnyView(AdaScriptRenderedView(model: model, performAction: { action in
                do {
                    if inputs.actions[action] != nil { inputs.perform(action) }
                    else { try resolved.perform(action: action) }
                    for (name, binding) in inputs.bindings { binding.wrappedValue = try resolved.readInput(name) }
                    revision.wrappedValue += 1
                } catch { inputs.context.report(UIDiagnostic(error.localizedDescription)) }
            }, catalog: catalog))
        } catch { return AnyView(Text(error.localizedDescription).foregroundColor(.red)) }
    }
}

extension UIValue {
    var scriptFieldValue: EditorFieldValue {
        switch self {
        case .null: .null
        case .bool(let value): .bool(value)
        case .number(let value): .double(value)
        case .string(let value): .string(value)
        case .array(let values): .array(values.map(\.scriptFieldValue))
        case .object(let values): .object(values.mapValues(\.scriptFieldValue))
        }
    }

    init(field: EditorFieldValue) {
        switch field {
        case .null: self = .null
        case .bool(let value): self = .bool(value)
        case .int(let value): self = .number(Double(value))
        case .double(let value): self = .number(value)
        case .string(let value): self = .string(value)
        case .array(let values): self = .array(values.map(Self.init(field:)))
        case .object(let values): self = .object(values.mapValues(Self.init(field:)))
        }
    }
}
