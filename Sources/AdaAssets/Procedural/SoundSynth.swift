//
//  SoundSynth.swift
//  AdaEngine
//

import Foundation

public enum Waveform: String, CaseIterable, Sendable {
    case sine, square, saw, triangle, noise
}

/// One oscillator with an ADSR envelope, an optional pitch sweep and vibrato, and simple filters.
public struct SoundVoice: Sendable, Equatable {
    public var wave: Waveform
    public var frequency: Float
    /// Frequency reached at the end of the voice; the pitch glides exponentially.
    public var endFrequency: Float?
    public var start: Float = 0
    public var duration: Float
    public var volume: Float = 0.8
    /// Pulse width of a square wave in `0.05...0.95`.
    public var duty: Float = 0.5
    public var attack: Float = 0.005
    public var decay: Float = 0
    public var sustain: Float = 1
    public var release: Float = 0.02
    public var vibratoRate: Float = 0
    /// Vibrato depth in semitones.
    public var vibratoDepth: Float = 0
    /// Cutoff in Hz; `nil` leaves the filter off.
    public var lowpass: Float?
    public var highpass: Float?

    public init(wave: Waveform, frequency: Float, duration: Float) {
        self.wave = wave
        self.frequency = frequency
        self.duration = duration
    }
}

public struct SoundEcho: Sendable, Equatable {
    public var delay: Float
    public var feedback: Float
    public var mix: Float

    public init(delay: Float, feedback: Float, mix: Float) {
        self.delay = delay
        self.feedback = feedback
        self.mix = mix
    }
}

public struct SoundSpec: Sendable, Equatable {
    public static let maximumDuration: Float = 30
    public static let maximumVoices = 256
    /// Sum of voice lengths; bounds the synthesis cost.
    public static let maximumVoiceSeconds: Float = 120

    public var sampleRate = 44_100
    public var voices: [SoundVoice] = []
    public var echo: SoundEcho?
    /// Loudest sample after rendering, in `0...1`.
    public var peak: Float = 0.9
    public var seed: UInt32 = 1

    public init() {}
}

public enum SoundSynthError: Error, Equatable, Sendable {
    case noVoices
    case tooLong(seconds: Float)
    case tooManyVoices
    case tooMuchVoiceTime
    case silent
}

public enum SoundSynth {
    /// Renders mono audio and scales it so the loudest sample equals `spec.peak`.
    public static func render(_ spec: SoundSpec) throws -> WAVAudio {
        guard !spec.voices.isEmpty else { throw SoundSynthError.noVoices }
        guard spec.voices.count <= SoundSpec.maximumVoices else { throw SoundSynthError.tooManyVoices }
        guard spec.voices.reduce(0, { $0 + $1.duration + $1.release }) <= SoundSpec.maximumVoiceSeconds else { throw SoundSynthError.tooMuchVoiceTime }
        let rate = Float(spec.sampleRate)
        let tail = echoTail(spec.echo)
        let end = (spec.voices.map { $0.start + $0.duration + $0.release }.max() ?? 0) + tail
        guard end <= SoundSpec.maximumDuration else { throw SoundSynthError.tooLong(seconds: end) }

        var output = [Float](repeating: 0, count: max(Int((end * rate).rounded(.up)), 1))
        for (index, voice) in spec.voices.enumerated() {
            mix(voice, rate: rate, seed: spec.seed &+ UInt32(index) &* 2_654_435_761, into: &output)
        }
        if let echo = spec.echo { applyEcho(echo, rate: rate, to: &output) }
        let loudest = output.reduce(0) { max($0, abs($1)) }
        guard loudest > 1e-6 else { throw SoundSynthError.silent }
        let scale = spec.peak / loudest
        for index in output.indices { output[index] *= scale }
        return WAVAudio(sampleRate: spec.sampleRate, channels: 1, samples: output)
    }

    private static func echoTail(_ echo: SoundEcho?) -> Float {
        guard let echo, echo.mix > 0 else { return 0 }
        guard echo.feedback > 0 else { return echo.delay }
        let repeats = min(20, Int((log(0.001) / log(max(echo.feedback, 0.01))).rounded(.up)))
        return echo.delay * Float(max(repeats, 1))
    }

    private static func applyEcho(_ echo: SoundEcho, rate: Float, to output: inout [Float]) {
        let delay = max(Int(echo.delay * rate), 1)
        var wet = [Float](repeating: 0, count: output.count)
        for index in output.indices {
            let previous = index >= delay ? wet[index - delay] : 0
            wet[index] = output[index] + echo.feedback * previous
            if index >= delay { output[index] += echo.mix * previous }
        }
    }

    private static func mix(_ voice: SoundVoice, rate: Float, seed: UInt32, into output: inout [Float]) {
        let first = Int((voice.start * rate).rounded())
        let sustainEnd = voice.duration
        let total = Int(((voice.duration + voice.release) * rate).rounded(.up))
        var phase: Float = 0
        // Hash the seed first: xorshift state must be non-zero and neighboring seeds must not collapse onto one stream.
        var noise = (seed ^ 0x9E37_79B9) &* 747_796_405 | 1
        var heldNoise: Float = 0
        var low: Float = 0
        var highLow: Float = 0
        let lowAlpha = voice.lowpass.map { 1 - exp(-2 * Float.pi * min($0, rate / 2) / rate) }
        let highAlpha = voice.highpass.map { 1 - exp(-2 * Float.pi * min($0, rate / 2) / rate) }
        for index in 0..<total where first + index < output.count {
            let time = Float(index) / rate
            var frequency = voice.frequency
            if let end = voice.endFrequency, voice.duration > 0, voice.frequency > 0, end > 0 {
                frequency = voice.frequency * pow(end / voice.frequency, min(time / voice.duration, 1))
            }
            if voice.vibratoDepth > 0, voice.vibratoRate > 0 {
                frequency *= pow(2, voice.vibratoDepth * sin(2 * Float.pi * voice.vibratoRate * time) / 12)
            }
            let step = min(frequency / rate, 0.5)
            phase += step
            phase -= phase.rounded(.down)
            var sample: Float
            switch voice.wave {
            case .sine: sample = sin(2 * Float.pi * phase)
            case .square: sample = phase < voice.duty ? 1 : -1
            case .saw: sample = 2 * phase - 1
            case .triangle: sample = 4 * abs(phase - 0.5) - 1
            case .noise:
                // Sample-and-hold white noise whose rate follows the voice frequency, so low values sound rumbly.
                if index == 0 || phase < step {
                    noise ^= noise << 13
                    noise ^= noise >> 17
                    noise ^= noise << 5
                    heldNoise = Float(noise) / Float(UInt32.max) * 2 - 1
                }
                sample = heldNoise
            }
            if let lowAlpha {
                low += lowAlpha * (sample - low)
                sample = low
            }
            if let highAlpha {
                highLow += highAlpha * (sample - highLow)
                sample -= highLow
            }
            output[first + index] += sample * voice.volume * envelope(voice, time: time, sustainEnd: sustainEnd)
        }
    }

    private static func envelope(_ voice: SoundVoice, time: Float, sustainEnd: Float) -> Float {
        let attack = max(voice.attack, 1e-4)
        var level: Float
        if time < attack {
            level = time / attack
        } else if time < attack + voice.decay {
            level = 1 + (voice.sustain - 1) * (time - attack) / max(voice.decay, 1e-4)
        } else {
            level = voice.sustain
        }
        if time > sustainEnd {
            let held = envelope(voice, time: sustainEnd, sustainEnd: .infinity)
            level = held * max(0, 1 - (time - sustainEnd) / max(voice.release, 1e-4))
        }
        return level
    }
}
