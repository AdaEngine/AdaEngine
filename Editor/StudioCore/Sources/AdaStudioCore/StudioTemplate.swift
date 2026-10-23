import Foundation

public enum StudioTemplate: String, CaseIterable, Sendable {
    case game2D, game3D
    public var title: String { self == .game3D ? "Новая 3D-игра" : "Новая 2D-игра" }

    public func makeProject(title: String? = nil) throws -> StudioSnapshot {
        let title = title ?? self.title
        let metadata: StudioValue = .object([
            "schemaVersion": .int(1),
            "project": .object(["id": .string(UUID().uuidString.lowercased()), "name": .string("StudioGame"), "displayName": .string(title)]),
            "build": .object(["system": .string("adascript")]),
            "paths": .object(["sources": .string("Sources"), "assets": .string("Assets"), "resourceRoots": .array([.string("Assets")])]),
            "runtime": .object(["moduleName": .string("StudioGame"), "entry": .object(["scene": .string("Assets/Scenes/Main.ascn")]),
                "plugins": .object(["preset": .string(self == .game3D ? "game3d" : "game2d"), "settings": .object([:])])]),
            "inputActions": .array([])
        ])
        var scene = StudioScene(value: .object([
            "format": .string("ada.scene"), "schemaVersion": .int(1),
            "scene": .object(["id": .string(UUID().uuidString.lowercased()), "name": .string(title)]), "entities": .array([])
        ]))
        _ = try scene.add(name: "Camera", components: [
            "AdaTransform.Transform": Self.transform(position: [0, 0, self == .game3D ? -8 : 0]),
            "AdaRender.Camera": .object(["projection": .string(self == .game3D ? "perspective" : "orthographic"), "isActive": .bool(true),
                "renderOrder": .int(0), "backgroundColor": Self.color(0.05, 0.08, 0.13)])
        ])
        if self == .game3D {
            _ = try scene.add(name: "Sun", components: [
                "AdaTransform.Transform": Self.transform(position: [0, 4, 4]),
                "AdaScene.DirectionalLightComponent": .object(["radiance": .array([.double(1), .double(1), .double(1)]), "intensity": .double(2)])
            ])
            _ = try scene.add(name: "Player", components: [
                "AdaTransform.Transform": Self.transform(),
                "AdaScene.Mesh3DComponent": .object(["mesh": .string("Cube"), "size": .double(1), "color": Self.color(0.16, 0.55, 1),
                    "metallic": .double(0), "roughness": .double(0.6)])
            ])
        } else {
            _ = try scene.add(name: "Player", components: [
                "AdaTransform.Transform": Self.transform(),
                "AdaSprite.Sprite": .object(["tintColor": Self.color(0.16, 0.55, 1), "size": .object(["width": .double(80), "height": .double(80)])])
            ])
        }
        let snapshot = StudioSnapshot(title: title, files: [
            .init(path: ".ada/project.json", data: try metadata.encoded()),
            .init(path: "Assets/Scenes/Main.ascn", data: try scene.encoded()),
            .init(path: "Sources/Game.ada", text: "// Ada Studio — describe your game in the chat to add gameplay.\n")
        ])
        try snapshot.validate()
        return snapshot
    }

    public static func transform(position: [Double] = [0, 0, 0]) -> StudioValue {
        .object(["position": .array(position.map(StudioValue.double)), "rotation": .array([.double(0), .double(0), .double(0), .double(1)]),
                 "scale": .array([.double(1), .double(1), .double(1)])])
    }
    public static func color(_ r: Double, _ g: Double, _ b: Double) -> StudioValue {
        .object(["red": .double(r), "green": .double(g), "blue": .double(b), "alpha": .double(1)])
    }
}
