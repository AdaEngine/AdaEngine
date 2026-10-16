import AdaAssets
@testable import AdaAudio
import Foundation
import miniaudio
import Testing

/// Generated WAV files must decode and play through the real audio engine, not just through our own reader.
@Suite("Generated audio playback")
struct GeneratedAudioTests {
    @Test("A synthesized sine decodes in the engine and renders audible PCM at the requested level")
    func engineDecodesSynthesizedWAV() throws {
        var spec = SoundSpec()
        spec.sampleRate = 22_050
        spec.peak = 0.5
        spec.voices = [SoundVoice(wave: .sine, frequency: 440, duration: 0.3)]
        let data = try WAVWriter().encode(SoundSynth.render(spec))

        let engine = try MiniAudioEngine(headless: true)
        let sound = try engine.makeSound(from: data)
        sound.start()
        var pcm = [Float](repeating: 0, count: 2 * 2400)
        var read: ma_uint64 = 0
        let result = unsafe pcm.withUnsafeMutableBufferPointer { ma_engine_read_pcm_frames(engine.engine.enginePtr, $0.baseAddress, 2400, &read) }
        #expect(result == MA_SUCCESS && read == 2400)
        let peak = pcm.map(abs).max() ?? 0
        #expect(peak > 0.3 && peak < 0.6, "peak \(peak)")
        sound.stop()
    }

    @Test("Asset loading accepts WAV files and the extension list covers common formats")
    func loadsWAVAsset() async throws {
        #expect(["wav", "mp3", "flac"].allSatisfy { AudioResource.extensions().contains($0) })
        unsafe AudioServer.shared = AudioServer(engine: try MiniAudioEngine(headless: true))
        var spec = SoundSpec()
        spec.voices = [SoundVoice(wave: .triangle, frequency: 330, duration: 0.2)]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratedAudio-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try WAVWriter().encode(SoundSynth.render(spec)).write(to: url)

        let resource = try #require(try await AssetsManager.load(AudioResource.self, at: url.path).asset)
        let controller = unsafe AudioServer.shared.prepareAudio(resource)
        controller.play()
        #expect(controller.isPlaying)
        controller.stop()
    }
}
