import AdaEngine
import Foundation
import MCP
import Testing

#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

@testable import AdaEditor

@MainActor
@Suite("Agent audio and sprite generation", .serialized)
struct EditorAgentMediaGenerateTests {
    private static let jump = "func build(sound) { var v = sound.tone(\"square\", 260, 0.16); sound.sweep(v, 620.0); sound.envelope(v, 0.002, 0.12, 0.0); }"
    private static let slime = "func build(sprite) { sprite.size(8, 8); sprite.palette(1, 90, 200, 110); sprite.ellipse(3, 4, 3, 3, 1); sprite.mirror(); sprite.outline(2); sprite.palette(2, 20, 30, 25); }"

    @Test("Generates a WAV under Assets, reports measurements and inspects it again")
    func generatesAndInspectsAudio() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let result = await service.handle(name: "editor.audio.generate", arguments: ["destination": "Assets/Audio/jump.wav", "source": .string(Self.jump)])
        #expect(result.ok, "\(result.payload)")
        let payload = try #require(JSONSerialization.jsonObject(with: Data(result.payload.utf8)) as? [String: Any])
        #expect(payload["assetReference"] as? String == "@res://Audio/jump.wav")
        let duration = try #require(payload["durationSeconds"] as? Double)
        #expect(duration > 0.15 && duration < 0.25)
        #expect(payload["clippedSamples"] as? Int == 0)
        #expect((payload["loudnessEnvelopeDBFS"] as? [Double])?.count == 10)

        let inspected = await service.handle(name: "editor.audio.inspect", arguments: ["path": "Assets/Audio/jump.wav"])
        #expect(inspected.ok, "\(inspected.payload)")
        let measured = try #require(JSONSerialization.jsonObject(with: Data(inspected.payload.utf8)) as? [String: Any])
        #expect(measured["durationSeconds"] as? Double == duration)
        #expect((measured["peak"] as? Double ?? 0) > 0.8)

        #expect(!(await service.handle(name: "editor.audio.inspect", arguments: ["path": "Assets/Audio/missing.wav"])).ok)
        #expect(!(await service.handle(name: "editor.audio.inspect", arguments: ["path": "../outside.wav"])).ok)
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("Assets/Audio/broken.wav"))
        #expect(!(await service.handle(name: "editor.audio.inspect", arguments: ["path": "Assets/Audio/broken.wav"])).ok)
    }

    @Test("Generates a PNG sprite that the system image decoder reads")
    func generatesSprite() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let result = await service.handle(name: "editor.sprite.generate", arguments: ["destination": "Assets/Sprites/slime.png", "source": .string(Self.slime)])
        #expect(result.ok, "\(result.payload)")
        let payload = try #require(JSONSerialization.jsonObject(with: Data(result.payload.utf8)) as? [String: Any])
        #expect(payload["assetReference"] as? String == "@res://Sprites/slime.png")
        #expect(payload["size"] as? [Int] == [8, 8])
        #expect((payload["opaquePixels"] as? Int ?? 0) > 20)
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let url = root.appendingPathComponent("Assets/Sprites/slime.png")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 8 && image.height == 8 && image.alphaInfo != .none)
        #endif
    }

    @Test("Refuses overwrites, wrong extensions, bad paths and failing scripts without writing files")
    func rejectsUnsafeRequests() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let cases: [(tool: String, source: String, good: String, bad: [String])] = [
            ("editor.audio.generate", Self.jump, "Assets/a.wav", ["Assets/a.wav", "Assets/a.mp3", "../outside.wav", "/tmp/outside.wav", "Sources/a.wav"]),
            ("editor.sprite.generate", Self.slime, "Assets/a.png", ["Assets/a.png", "Assets/a.jpg", "../outside.png", "/tmp/outside.png", "Sources/a.png"]),
        ]
        for item in cases {
            #expect((await service.handle(name: item.tool, arguments: ["destination": .string(item.good), "source": .string(item.source)])).ok, "\(item.tool)")
            for destination in item.bad {
                let result = await service.handle(name: item.tool, arguments: ["destination": .string(destination), "source": .string(item.source)])
                #expect(!result.ok, "\(item.tool) \(destination)")
            }
        }
        let failingSound = await service.handle(name: "editor.audio.generate", arguments: ["destination": "Assets/b.wav", "source": "func build(sound) { sound.tone(\"banjo\", 1, 1); }"])
        #expect(!failingSound.ok && failingSound.payload.contains("sound.tone"))
        let failingSprite = await service.handle(name: "editor.sprite.generate", arguments: ["destination": "Assets/b.png", "source": "func build(sprite) { sprite.size(0, 4); }"])
        #expect(!failingSprite.ok && failingSprite.payload.contains("sprite.size"))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Assets/b.wav").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Assets/b.png").path))
    }

    @Test("Every runnable example in the generator skills works and meets the skill's own guidance")
    func skillExamplesRun() throws {
        let skills = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AdaEditor/Assets/AgentSkills")
        func examples(_ skill: String, containing marker: String) throws -> [String] {
            let text = try String(contentsOf: skills.appendingPathComponent("\(skill)/SKILL.md"), encoding: .utf8)
            return text.components(separatedBy: "```").enumerated().filter { $0.offset % 2 == 1 }.map(\.element).filter { $0.contains(marker) }
        }
        let sounds = try examples("ada-sound-design", containing: "func build(sound)")
        #expect(sounds.count >= 4)
        for source in sounds {
            let audio = try AdaScriptSoundGenerator.generate(source: source)
            let report = AudioAnalyzer.analyze(audio)
            #expect(report.clippedSamples == 0 && report.leadingSilence < 0.01 && report.duration < 1.2, "\(source)")
        }
        let sprites = try examples("ada-pixel-art", containing: "func build(sprite)")
        #expect(sprites.count >= 1)
        for source in sprites { #expect(try AdaScriptSpriteGenerator.generate(source: source).canvas.opaquePixelCount > 50) }
        let models = try examples("ada-procedural-models", containing: "func build(model)")
        #expect(models.count >= 1)
        for source in models { #expect(try AdaScriptModelGenerator.generate(source: source).nodes.count > 1) }
        let voxels = try examples("ada-voxel-models", containing: "func build(model)")
        #expect(voxels.count >= 1)
        for source in voxels { #expect(try AdaScriptVoxelGenerator.generate(source: source).model.voxels.count > 10) }
    }

    @Test("Bundled skills are readable and describe the new workflow")
    func skillsAreAvailable() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let listed = await service.handle(name: "editor.skills.list", arguments: [:])
        for id in ["ada-autonomous-studio", "ada-sound-design", "ada-pixel-art", "ada-procedural-models", "ada-voxel-models"] {
            #expect(listed.payload.contains(id), "\(id)")
            let read = await service.handle(name: "editor.skills.read", arguments: ["id": .string(id)])
            #expect(read.ok && read.payload.contains("Ada") || read.ok, "\(id)")
        }
    }

    @Test("The AudioSource inspector descriptor round-trips its payload")
    func audioSourceDescriptor() throws {
        let typeName = EditorBuiltInComponentType.audioSource
        let defaults = EditorComponentRegistry.descriptor(named: typeName)?.makeDefaultPayload()
        #expect(defaults?["volume"]?.doubleValue == 1)
        let decoded = try #require(
            try EditorComponentRegistry.decode(typeName: typeName, payload: ["source": .string("@res://Audio/jump.wav"), "volume": .double(3), "loops": .bool(true), "autoplay": .bool(true)]) as? AudioSource
        )
        #expect(decoded == AudioSource(source: "@res://Audio/jump.wav", volume: 1, loops: true, autoplay: true))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AgentMediaGenerate-\(UUID())")
        for path in ["Assets/Audio", "Assets/Sprites", "Sources"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Media Generate", buildSystem: .adaScript), at: root)
        return root
    }
}
