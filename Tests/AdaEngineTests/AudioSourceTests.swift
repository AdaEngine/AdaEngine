import AdaEngine
@_spi(Internal) @testable import AdaApp
@testable import AdaAudio
import Foundation
import Testing

@MainActor
@Suite("Audio source component", .serialized)
struct AudioSourceTests {
    private static func makeApp() async throws -> AppWorlds {
        unsafe AudioServer.shared = AudioServer(engine: try MiniAudioEngine(headless: true))
        AudioSource.registerComponent()
        AudioSourceState.registerComponent()
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin())
        try await app.build()
        app.addSystem(AudioSourceSystem.self)
        return app
    }

    private static func writeSound() throws -> URL {
        var spec = SoundSpec()
        spec.voices = [SoundVoice(wave: .sine, frequency: 523, duration: 0.5)]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AudioSource-\(UUID()).wav")
        try WAVWriter().encode(SoundSynth.render(spec)).write(to: url)
        return url
    }

    /// Runs updates until `condition` holds; the system loads asynchronously and applies results through commands.
    private static func run(_ app: AppWorlds, until condition: () -> Bool) async throws {
        for _ in 0..<60 where !condition() {
            await app.main.runScheduler(.update, deltaTime: 1 / 60)
            try await Task.sleep(for: .milliseconds(20))
        }
        await app.main.runScheduler(.update, deltaTime: 1 / 60)
    }

    @Test("The component keeps its fields when scenes are saved and loaded")
    func codable() throws {
        let source = AudioSource(source: "@res://Audio/jump.wav", volume: 0.4, loops: true, autoplay: true)
        let decoded = try JSONDecoder().decode(AudioSource.self, from: JSONEncoder().encode(source))
        #expect(decoded == source)
        #expect(AudioSource().autoplay == false && AudioSource().volume == 1)
    }

    @Test("Autoplay starts a loaded sound, and play and stop requests are consumed")
    func playsAndStops() async throws {
        let app = try await Self.makeApp()
        let url = try Self.writeSound()
        defer { try? FileManager.default.removeItem(at: url) }
        let entity = app.main.spawn("Music") {
            AudioSource(source: url.path, volume: 0.5, loops: true, autoplay: true)
            Transform()
        }
        try await Self.run(app) { entity.components[AudioSourceState.self]?.isPlaying == true }
        let state = try #require(entity.components[AudioSourceState.self])
        #expect(state.error == nil && state.path == url.path)
        #expect(state.isPlaying)

        entity.components[AudioSource.self]?.stop = true
        try await Self.run(app) { entity.components[AudioSource.self]?.stop == false }
        #expect(entity.components[AudioSourceState.self]?.isPlaying == false)

        entity.components[AudioSource.self]?.play = true
        try await Self.run(app) { entity.components[AudioSource.self]?.play == false }
        #expect(entity.components[AudioSourceState.self]?.isPlaying == true)
    }

    @Test("A missing file is reported on the state instead of crashing, and removing the component stops playback")
    func errorsAndRemoval() async throws {
        let app = try await Self.makeApp()
        let broken = app.main.spawn("Broken") { AudioSource(source: "/nonexistent/sound.wav", autoplay: true) }
        let url = try Self.writeSound()
        defer { try? FileManager.default.removeItem(at: url) }
        let working = app.main.spawn("Working") { AudioSource(source: url.path, autoplay: true) }
        try await Self.run(app) {
            broken.components[AudioSourceState.self]?.error != nil && working.components[AudioSourceState.self]?.isPlaying == true
        }
        #expect(broken.components[AudioSourceState.self]?.error != nil)
        #expect(working.components[AudioSourceState.self]?.isPlaying == true)

        working.components[AudioSource.self] = nil
        try await Self.run(app) { working.components[AudioSourceState.self] == nil }
        #expect(working.components[AudioSourceState.self] == nil)
    }
}
