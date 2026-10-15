import AdaRender
import AdaUtils
import Foundation

/// Compares rendered frames against checked-in reference PNGs.
///
/// References live in `GoldenFrames/<backend>/<name>.png` next to the tests. Set
/// `ADAENGINE_GOLDEN_RECORD=1` to (re)write them from the current output, and
/// `ADAENGINE_GOLDEN_OUTPUT=<dir>` to choose where actual and difference images go on a mismatch.
/// Tolerances are per backend because GPUs differ in rounding; Metal is the reference backend.
struct GoldenFrame {
    struct Tolerance: Sendable, Equatable {
        /// Largest allowed per-channel difference, in 8-bit steps, before a pixel counts as different.
        var channelSteps: Int
        /// Fraction of pixels allowed to differ by more than `channelSteps`.
        var differingFraction: Double

        /// Same-GPU reruns are expected to match; the slack absorbs driver rounding only.
        static let metal = Self(channelSteps: 2, differingFraction: 0.0005)
    }

    struct Comparison: Equatable {
        var differingPixels: Int
        var totalPixels: Int
        var largestStep: Int
        var sizeMismatch: Bool

        func passes(_ tolerance: Tolerance) -> Bool {
            !sizeMismatch && Double(differingPixels) <= Double(totalPixels) * tolerance.differingFraction
        }
    }

    enum Outcome: Equatable {
        case recorded(URL)
        case matched(Comparison)
        case mismatched(Comparison, actual: URL, difference: URL)
        case missingReference(actual: URL)
    }

    static var isRecording: Bool { ProcessInfo.processInfo.environment["ADAENGINE_GOLDEN_RECORD"] == "1" }

    static var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["ADAENGINE_GOLDEN_OUTPUT"] ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func referenceURL(backend: String, name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("GoldenFrames/\(backend)/\(name).png")
    }

    private static func step(_ left: Color, _ right: Color) -> Int {
        max(
            abs(Int((left.red * 255).rounded()) - Int((right.red * 255).rounded())),
            abs(Int((left.green * 255).rounded()) - Int((right.green * 255).rounded())),
            abs(Int((left.blue * 255).rounded()) - Int((right.blue * 255).rounded()))
        )
    }

    /// Per-pixel comparison in 8-bit RGB. Alpha is ignored because presentation targets are opaque.
    static func compare(_ actual: Image, _ reference: Image, tolerance: Tolerance) -> Comparison {
        guard actual.width == reference.width, actual.height == reference.height else {
            let total = actual.width * actual.height
            return Comparison(differingPixels: total, totalPixels: total, largestStep: 255, sizeMismatch: true)
        }
        var differing = 0
        var largest = 0
        for y in 0..<actual.height {
            for x in 0..<actual.width {
                let step = step(actual.getPixel(x: x, y: y), reference.getPixel(x: x, y: y))
                largest = max(largest, step)
                if step > tolerance.channelSteps {
                    differing += 1
                }
            }
        }
        return Comparison(differingPixels: differing, totalPixels: actual.width * actual.height, largestStep: largest, sizeMismatch: false)
    }

    /// Red where pixels differ beyond tolerance, dimmed actual image elsewhere.
    static func differenceImage(_ actual: Image, _ reference: Image, tolerance: Tolerance) -> Image {
        var result = Image(width: actual.width, height: actual.height, color: .black, format: .rgba8)
        guard actual.width == reference.width, actual.height == reference.height else {
            return result
        }
        for y in 0..<actual.height {
            for x in 0..<actual.width {
                let left = actual.getPixel(x: x, y: y)
                let different = step(left, reference.getPixel(x: x, y: y)) > tolerance.channelSteps
                let shade = (left.red + left.green + left.blue) / 3 * 0.35
                result.setPixel(in: [Float(x), Float(y)], color: different ? Color(red: 1, green: 0, blue: 0) : Color(red: shade, green: shade, blue: shade))
            }
        }
        return result
    }

    static func check(_ actual: Image, name: String, backend: String = "metal", tolerance: Tolerance = .metal) throws -> Outcome {
        let reference = referenceURL(backend: backend, name: name)
        if isRecording {
            try FileManager.default.createDirectory(at: reference.deletingLastPathComponent(), withIntermediateDirectories: true)
            try actual.writePNG(to: reference)
            return .recorded(reference)
        }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let actualURL = outputDirectory.appendingPathComponent("\(name)-actual.png")
        guard FileManager.default.fileExists(atPath: reference.path) else {
            try actual.writePNG(to: actualURL)
            return .missingReference(actual: actualURL)
        }
        let expected = try Image(contentsOf: reference)
        let comparison = compare(actual, expected, tolerance: tolerance)
        if comparison.passes(tolerance) {
            return .matched(comparison)
        }
        let differenceURL = outputDirectory.appendingPathComponent("\(name)-difference.png")
        try actual.writePNG(to: actualURL)
        try differenceImage(actual, expected, tolerance: tolerance).writePNG(to: differenceURL)
        return .mismatched(comparison, actual: actualURL, difference: differenceURL)
    }
}
