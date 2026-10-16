import AdaSpineRuntime
import Foundation

/// Exports actual runtime poses for a portable visual preview, without substituting animation in JavaScript.
@main
struct SpinePreview {
    struct Draw: Encodable {
        let page: Int
        let blend: Int
        let pma: Bool
        let vertices: [[Float]]
        let indices: [UInt32]
    }
    struct Frame: Encodable {
        let draws: [Draw]
        let bones: [[Float]]
    }
    struct Clip: Encodable {
        let name: String
        let fps: Int
        let frames: [Frame]
    }
    struct Preview: Encodable {
        let source = "AdaSpineRuntime / official Spine C 4.2"
        let clips: [Clip]
    }

    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            print("Usage: swift run SpinePreview <output-directory>")
            return
        }
        let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let assets = Bundle.module.resourceURL?.appendingPathComponent("Assets") else {
            throw SpineError.invalidData("Preview assets are missing.")
        }
        let skeleton = try Data(contentsOf: assets.appendingPathComponent("spineboy-pro.skel"))
        let atlas = try String(contentsOf: assets.appendingPathComponent("spineboy.atlas"), encoding: .utf8)
        let player = try SpineAnimationPlayer(skeleton: skeleton, atlas: atlas, format: .binary)
        print("Animations: \(player.animationNames.joined(separator: ", "))")
        let fps = 30
        var clips: [Clip] = []
        for name in ["idle", "walk", "run", "jump"] where player.animationNames.contains(name) {
            player.resetToSetupPose()
            try player.play(name, repeats: name != "jump", transitionDuration: 0)
            var frames: [Frame] = []
            for index in 0..<60 {
                if index > 0 { player.advance(by: 1 / Float(fps)) }
                frames.append(Frame(
                    draws: player.snapshot().map { draw in
                        Draw(page: draw.pageIndex, blend: draw.blendMode.rawValue, pma: draw.premultipliedAlpha,
                             vertices: draw.vertices.map { vertex in
                                 [round(vertex.x), round(vertex.y), round(vertex.u), round(vertex.v),
                                  round(vertex.red), round(vertex.green), round(vertex.blue), round(vertex.alpha),
                                  round(vertex.darkRed), round(vertex.darkGreen), round(vertex.darkBlue), round(vertex.darkAlpha)]
                             }, indices: draw.indices)
                    },
                    bones: player.boneSnapshot().filter(\.isActive).map { [round($0.x), round($0.y), round($0.endX), round($0.endY)] }
                ))
            }
            clips.append(Clip(name: name, fps: fps, frames: frames))
        }
        let data = try JSONEncoder().encode(Preview(clips: clips))
        try data.write(to: output.appendingPathComponent("poses.json"))
        var script = Data("window.SPINE_PREVIEW_DATA=".utf8)
        script.append(data)
        script.append(Data(";".utf8))
        try script.write(to: output.appendingPathComponent("poses.js"))
        for name in ["spineboy.png", "preview.html", "SpineRuntime-LICENSE.txt", "UPSTREAM.md"] {
            let content = try Data(contentsOf: assets.appendingPathComponent(name))
            let destination = name == "preview.html" ? "index.html" : name
            try content.write(to: output.appendingPathComponent(destination))
        }
        print("Exported \(clips.count) animations / \(clips.reduce(0) { $0 + $1.frames.count }) runtime frames to \(output.path)")
    }

    private static func round(_ value: Float) -> Float { (value * 100_000).rounded() / 100_000 }
}
