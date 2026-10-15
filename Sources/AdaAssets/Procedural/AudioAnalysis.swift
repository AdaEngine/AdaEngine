//
//  AudioAnalysis.swift
//  AdaEngine
//

import Foundation

/// Objective measurements of an audio clip, so a program can check a sound without listening to it.
public struct AudioReport: Sendable, Equatable {
    public var duration: Double
    public var sampleRate: Int
    public var channels: Int
    /// Highest absolute sample in `0...1`.
    public var peak: Float
    public var peakDecibels: Float
    public var rmsDecibels: Float
    /// Samples at or beyond full scale; a clip with many of these is distorted.
    public var clippedSamples: Int
    public var dcOffset: Float
    /// Seconds below -60 dBFS at the start and end.
    public var leadingSilence: Double
    public var trailingSilence: Double
    /// Strongest frequency of the loudest half second, in Hz.
    public var dominantFrequency: Double
    /// Brightness: the magnitude-weighted mean frequency of the loudest half second, in Hz.
    public var spectralCentroid: Double
    /// RMS level in dBFS for ten equal slices, showing the loudness shape (attack, decay, tail).
    public var envelope: [Float]
}

public enum AudioAnalyzer {
    static let silenceThreshold: Float = 0.001

    public static func analyze(_ audio: WAVAudio) -> AudioReport {
        let mono = audio.mono
        let peak = audio.samples.reduce(0) { max($0, abs($1)) }
        let energy = audio.samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = audio.samples.isEmpty ? 0 : Float((energy / Double(audio.samples.count)).squareRoot())
        let mean = audio.samples.isEmpty ? 0 : audio.samples.reduce(0, +) / Float(audio.samples.count)
        let first = mono.firstIndex { abs($0) > silenceThreshold }
        let last = mono.lastIndex { abs($0) > silenceThreshold }
        let rate = Double(max(audio.sampleRate, 1))
        let spectrum = loudestSpectrum(mono)
        return AudioReport(
            duration: audio.duration,
            sampleRate: audio.sampleRate,
            channels: audio.channels,
            peak: peak,
            peakDecibels: decibels(peak),
            rmsDecibels: decibels(rms),
            clippedSamples: audio.samples.filter { abs($0) >= 0.999 }.count,
            dcOffset: mean,
            leadingSilence: first.map { Double($0) / rate } ?? audio.duration,
            trailingSilence: last.map { Double(mono.count - 1 - $0) / rate } ?? audio.duration,
            dominantFrequency: spectrum.map { $0.peak * rate / Double($0.size) } ?? 0,
            spectralCentroid: spectrum.map { $0.centroid * rate / Double($0.size) } ?? 0,
            envelope: (0..<10).map { slice -> Float in
                let range = (slice * mono.count / 10)..<((slice + 1) * mono.count / 10)
                guard !range.isEmpty else { return -120 }
                return decibels(Float((range.reduce(0.0) { $0 + Double(mono[$1]) * Double(mono[$1]) } / Double(range.count)).squareRoot()))
            }
        )
    }

    private static func decibels(_ linear: Float) -> Float { linear > 1e-6 ? 20 * log10(linear) : -120 }

    /// Peak and centroid in FFT bins for the loudest 4096-sample window.
    private static func loudestSpectrum(_ samples: [Float]) -> (peak: Double, centroid: Double, size: Int)? {
        let size = 4096
        guard samples.count >= 64 else { return nil }
        let length = min(size, 1 << Int(log2(Double(samples.count))))
        var best = 0
        var bestEnergy: Float = -1
        for start in stride(from: 0, through: samples.count - length, by: max(length / 2, 1)) {
            let energy = samples[start..<(start + length)].reduce(0) { $0 + $1 * $1 }
            if energy > bestEnergy { (best, bestEnergy) = (start, energy) }
        }
        guard bestEnergy > 0 else { return nil }
        var real = (0..<length).map { index in samples[best + index] * Float(0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(length - 1))) }
        var imaginary = [Float](repeating: 0, count: length)
        fft(&real, &imaginary)
        let magnitudes = (0..<(length / 2)).map { (real[$0] * real[$0] + imaginary[$0] * imaginary[$0]).squareRoot() }
        guard let peakBin = magnitudes.indices.dropFirst().max(by: { magnitudes[$0] < magnitudes[$1] }) else { return nil }
        let total = magnitudes.dropFirst().reduce(0, +)
        let centroid = total > 0 ? magnitudes.indices.dropFirst().reduce(0.0) { $0 + Double($1) * Double(magnitudes[$1]) } / Double(total) : 0
        return (Double(peakBin), centroid, length)
    }

    /// In-place radix-2 FFT; the length must be a power of two.
    static func fft(_ real: inout [Float], _ imaginary: inout [Float]) {
        let count = real.count
        var swap = 0
        for index in 1..<count {
            var bit = count >> 1
            while swap & bit != 0 {
                swap ^= bit
                bit >>= 1
            }
            swap ^= bit
            if index < swap {
                real.swapAt(index, swap)
                imaginary.swapAt(index, swap)
            }
        }
        var length = 2
        while length <= count {
            let angle = -2 * Float.pi / Float(length)
            for start in stride(from: 0, to: count, by: length) {
                for offset in 0..<(length / 2) {
                    let (cosine, sine) = (cos(angle * Float(offset)), sin(angle * Float(offset)))
                    let (a, b) = (start + offset, start + offset + length / 2)
                    let (tr, ti) = (real[b] * cosine - imaginary[b] * sine, real[b] * sine + imaginary[b] * cosine)
                    (real[b], imaginary[b]) = (real[a] - tr, imaginary[a] - ti)
                    (real[a], imaginary[a]) = (real[a] + tr, imaginary[a] + ti)
                }
            }
            length <<= 1
        }
    }
}
