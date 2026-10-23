import AdaAssets
import Foundation
import Gravity

/// Runs an agent-authored AdaScript `build(sound)` function in an isolated VM and renders the voices it describes.
///
/// The script sees only the `sound` builder (voices, envelopes, filters, echo) and the limits of
/// ``AdaScriptGeneratorRunner``. Encoding and writing the `.wav` stay with the host (see ``WAVWriter``).
@MainActor
public enum AdaScriptSoundGenerator {
    public static func generate(source: String) throws -> WAVAudio {
        let bridge = AdaScriptSoundBridge()
        try AdaScriptGeneratorRunner.run(source: source, kind: "sound", bridge: bridge, prelude: builderPrelude, factory: "__ada_make_sound_builder")
        if let failure = bridge.failure { throw AdaScriptError.invalidManifest(failure) }
        do {
            return try SoundSynth.render(bridge.spec)
        } catch let error as SoundSynthError {
            throw AdaScriptError.invalidManifest(describe(error))
        }
    }

    private static func describe(_ error: SoundSynthError) -> String {
        switch error {
        case .noVoices: "The script created no voices; call sound.tone(wave, frequency, duration)."
        case .tooLong(let seconds): "The sound is \(Int(seconds)) seconds long; the limit is \(Int(SoundSpec.maximumDuration))."
        case .tooManyVoices: "A sound has at most \(SoundSpec.maximumVoices) voices."
        case .tooMuchVoiceTime: "The voices add up to more than \(Int(SoundSpec.maximumVoiceSeconds)) seconds of synthesis; shorten or remove voices."
        case .silent: "The sound is silent; check volumes, envelope sustain and filter cutoffs."
        }
    }

    // Parameter validation lives in the bridge; the script-side wrapper only forwards positional values.
    private static let builderPrelude = """

        class __AdaSoundBuilder {
            var __host;
            func init(host) { __host = host; }
            func rate(hz) { return __host.setRate(hz); }
            func seed(value) { return __host.setSeed(value); }
            func peak(level) { return __host.setPeak(level); }
            func pitch(midi) { return __host.midiToFrequency(midi); }
            func tone(wave, frequency, duration) { return __host.addTone(wave, frequency, duration); }
            func at(id, start) { return __host.setStart(id, start); }
            func volume(id, level) { return __host.setVolume(id, level); }
            func duty(id, width) { return __host.setDuty(id, width); }
            func envelope(id, attack, decay, sustain) { return __host.setEnvelope(id, attack, decay, sustain); }
            func release(id, seconds) { return __host.setRelease(id, seconds); }
            func sweep(id, endFrequency) { return __host.setSweep(id, endFrequency); }
            func vibrato(id, rate, semitones) { return __host.setVibrato(id, rate, semitones); }
            func lowpass(id, hz) { return __host.setLowpass(id, hz); }
            func highpass(id, hz) { return __host.setHighpass(id, hz); }
            func echo(delay, feedback, mix) { return __host.setEcho(delay, feedback, mix); }
        }
        func __ada_make_sound_builder(host) { return __AdaSoundBuilder(host); }
        """
}

// Only the owning main-actor generator touches this bridge, inside the shared VM lock.
@GSExportable("AdaSoundBuilderHost")
final class AdaScriptSoundBridge {
    @GSExportableIgnore var failure: String?
    @GSExportableIgnore var spec = SoundSpec()

    init() {}

    func setRate(hz: GSValue) -> Bool {
        guard let hz = whole(hz), (8000...48000).contains(hz) else { return fail("sound.rate expects a whole number in 8000...48000.") }
        spec.sampleRate = hz
        return true
    }

    func setSeed(value: GSValue) -> Bool {
        guard let value = whole(value), (0...1_000_000).contains(value) else { return fail("sound.seed expects a whole number in 0...1000000.") }
        spec.seed = UInt32(value)
        return true
    }

    func setPeak(level: GSValue) -> Bool {
        guard let level = range(level, 0.01...1) else { return fail("sound.peak expects a level in 0.01...1.") }
        spec.peak = level
        return true
    }

    func midiToFrequency(midi: GSValue) -> Double {
        guard let midi = midi.finiteNumber, (0...127).contains(midi) else {
            _ = fail("sound.pitch expects a MIDI note in 0...127 (69 is A4 at 440 Hz).")
            return 0
        }
        return 440 * pow(2, (midi - 69) / 12)
    }

    func addTone(wave: GSValue, frequency: GSValue, duration: GSValue) -> Int {
        guard wave.isString, let waveform = Waveform(rawValue: wave.toString) else {
            return failed("sound.tone expects a wave of \(Waveform.allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        guard let frequency = range(frequency, 1...20000), let duration = range(duration, 0.01...Double(SoundSpec.maximumDuration)) else {
            return failed("sound.tone expects a frequency in 1...20000 Hz and a duration in 0.01...\(Int(SoundSpec.maximumDuration)) seconds.")
        }
        guard spec.voices.count < SoundSpec.maximumVoices else { return failed("A sound has at most \(SoundSpec.maximumVoices) voices.") }
        spec.voices.append(SoundVoice(wave: waveform, frequency: frequency, duration: duration))
        return spec.voices.count - 1
    }

    func setStart(id: GSValue, start: GSValue) -> Bool {
        update(id, start, 0...Double(SoundSpec.maximumDuration), "sound.at expects a voice id and a start in seconds.") { $0.start = $1 }
    }

    func setVolume(id: GSValue, level: GSValue) -> Bool {
        update(id, level, 0...1, "sound.volume expects a voice id and a level in 0...1.") { $0.volume = $1 }
    }

    func setDuty(id: GSValue, width: GSValue) -> Bool {
        update(id, width, 0.05...0.95, "sound.duty expects a voice id and a pulse width in 0.05...0.95.") { $0.duty = $1 }
    }

    func setRelease(id: GSValue, seconds: GSValue) -> Bool {
        update(id, seconds, 0...5, "sound.release expects a voice id and seconds in 0...5.") { $0.release = $1 }
    }

    func setSweep(id: GSValue, endFrequency: GSValue) -> Bool {
        update(id, endFrequency, 1...20000, "sound.sweep expects a voice id and an end frequency in 1...20000 Hz.") { $0.endFrequency = $1 }
    }

    func setLowpass(id: GSValue, hz: GSValue) -> Bool {
        update(id, hz, 20...20000, "sound.lowpass expects a voice id and a cutoff in 20...20000 Hz.") { $0.lowpass = $1 }
    }

    func setHighpass(id: GSValue, hz: GSValue) -> Bool {
        update(id, hz, 20...20000, "sound.highpass expects a voice id and a cutoff in 20...20000 Hz.") { $0.highpass = $1 }
    }

    func setEnvelope(id: GSValue, attack: GSValue, decay: GSValue, sustain: GSValue) -> Bool {
        guard let index = voiceIndex(id), let attack = range(attack, 0...5), let decay = range(decay, 0...5), let sustain = range(sustain, 0...1) else {
            return fail("sound.envelope expects a voice id, attack and decay in 0...5 seconds and a sustain level in 0...1.")
        }
        spec.voices[index].attack = attack
        spec.voices[index].decay = decay
        spec.voices[index].sustain = sustain
        return true
    }

    func setVibrato(id: GSValue, rate: GSValue, semitones: GSValue) -> Bool {
        guard let index = voiceIndex(id), let rate = range(rate, 0.1...30), let depth = range(semitones, 0...12) else {
            return fail("sound.vibrato expects a voice id, a rate in 0.1...30 Hz and a depth in 0...12 semitones.")
        }
        spec.voices[index].vibratoRate = rate
        spec.voices[index].vibratoDepth = depth
        return true
    }

    func setEcho(delay: GSValue, feedback: GSValue, mix: GSValue) -> Bool {
        guard let delay = range(delay, 0.02...1), let feedback = range(feedback, 0...0.9), let mix = range(mix, 0...1) else {
            return fail("sound.echo expects a delay in 0.02...1 seconds, feedback in 0...0.9 and mix in 0...1.")
        }
        spec.echo = SoundEcho(delay: delay, feedback: feedback, mix: mix)
        return true
    }

    // MARK: - Helpers

    @GSExportableIgnore
    private func update(_ id: GSValue, _ value: GSValue, _ bounds: ClosedRange<Double>, _ message: String, _ apply: (inout SoundVoice, Float) -> Void) -> Bool {
        guard let index = voiceIndex(id), let value = range(value, bounds) else { return fail(message) }
        apply(&spec.voices[index], value)
        return true
    }

    @GSExportableIgnore
    private func fail(_ message: String) -> Bool {
        failure = failure ?? message
        return false
    }

    @GSExportableIgnore
    private func failed(_ message: String) -> Int {
        _ = fail(message)
        return -1
    }

    @GSExportableIgnore
    private func whole(_ value: GSValue) -> Int? {
        guard let number = value.finiteNumber, number == number.rounded() else { return nil }
        return Int(number)
    }

    @GSExportableIgnore
    private func voiceIndex(_ value: GSValue) -> Int? {
        whole(value).flatMap { spec.voices.indices.contains($0) ? $0 : nil }
    }

    @GSExportableIgnore
    private func range(_ value: GSValue, _ bounds: ClosedRange<Double>) -> Float? {
        value.finiteNumber.flatMap { bounds.contains($0) ? Float($0) : nil }
    }
}
