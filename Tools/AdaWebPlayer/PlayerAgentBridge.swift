import AdaA2UI
import AdaAssets
import AdaScriptCompilerCore
import AdaScripting
import AdaUIDescription
import Foundation
#if os(WASI)
import JavaScriptKit
#endif

/// Fixed host tools: no filesystem, network or credentials are exposed to generator scripts.
@MainActor
final class PlayerAgentBridge {
    #if os(WASI)
    private var callback: JSClosure?
    #endif

    func install() {
        #if os(WASI)
        guard JSObject.global["__adaStudioPreview"].boolean == true else { return }
        let handler = JSClosure { [weak self] values in
            let input = values.first?.string ?? "{}"
            let result = MainActor.assumeIsolated { self?.execute(input) ?? "{\"error\":\"Host closed\"}" }
            return .string(result)
        }
        callback = handler
        JSObject.global["__adaStudioTool"] = handler.jsValue
        #endif
    }

    func execute(_ input: String) -> String {
        do {
            guard input.utf8.count <= 1_048_576,
                  let fields = try JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any],
                  let name = fields["name"] as? String else {
                throw Failure("Invalid tool request")
            }
            let result = try run(name, fields)
            return String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self)
        } catch {
            let value = ["error": String(describing: error)]
            return (try? String(decoding: JSONSerialization.data(withJSONObject: value), as: UTF8.self)) ?? "{}"
        }
    }

    private func run(_ name: String, _ fields: [String: Any]) throws -> [String: Any] {
        if name == "api-describe" {
            let query = (fields["query"] as? String ?? "").lowercased()
            let environment = AdaScriptTypeEnvironment.standard
            let types = environment.members.keys.sorted().filter { query.isEmpty || $0.lowercased().contains(query) }
            return ["source": "Linked AdaScript compiler type environment", "types": types.prefix(30).map { type in
                ["name": type, "members": (environment.members[type] ?? [:]).sorted { $0.key < $1.key }.map { name, member in
                    ["name": name, "type": member.type.displayName, "description": member.detail ?? "", "insertText": member.insertText ?? name]
                }] as [String: Any]
            }]
        }
        if name == "a2ui-export" {
            guard let surface = fields["surface"] as? [String: Any], let id = surface["id"] as? String,
                  let components = surface["components"] as? [[String: Any]], let model = surface["data"] as? [String: Any] else {
                throw Failure("Invalid UI surface")
            }
            let client = A2UIClient()
            let envelopes: [[String: Any]] = [
                ["version": "v0.9.1", "createSurface": ["surfaceId": id, "catalogId": A2UIClient.catalogID]],
                ["version": "v0.9.1", "updateComponents": ["surfaceId": id, "components": components]],
                ["version": "v0.9.1", "updateDataModel": ["surfaceId": id, "value": model]]
            ]
            for envelope in envelopes { try client.receive(JSONSerialization.data(withJSONObject: envelope)) }
            guard let view = client.surfaces[id] else { throw Failure("Surface not created") }
            return ["content": try view.snapshot().encodedYAML()]
        }
        guard let source = fields["source"] as? String, source.utf8.count <= 65_536 else { throw Failure("Missing generator source (maximum 64 KiB)") }
        let data: Data
        switch name {
        case "editor_sprite_generate":
            let result = try AdaScriptSpriteGenerator.generate(source: source)
            data = try PNGWriter().encode(width: result.canvas.width, height: result.canvas.height, rgba: result.canvas.rgba())
        case "editor_audio_generate":
            data = try WAVWriter().encode(AdaScriptSoundGenerator.generate(source: source))
        case "editor_model_generate":
            data = try GLBWriter().encode(AdaScriptModelGenerator.generate(source: source))
        case "editor_voxel_generate":
            let result = try AdaScriptVoxelGenerator.generate(source: source)
            data = try VOXWriter().encode(model: result.model, palette: result.palette)
        default: throw Failure("Unavailable host tool: " + name)
        }
        guard data.count <= 16 * 1024 * 1024 else { throw Failure("Generated asset exceeds 16 MiB") }
        return ["data": data.base64EncodedString(), "bytes": data.count]
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
