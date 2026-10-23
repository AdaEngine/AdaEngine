@_spi(AdaEngine) import AdaEngine
import Foundation

/// A completed game frame handed to the scenario runner.
struct EditorScenarioFrame {
    let image: Image
    let sequence: Int
    let sourceWidth: Int
    let sourceHeight: Int
    let activeCameras: [String]
}

/// The running game a scenario drives: either an isolated offscreen runtime or the visible Play game.
@MainActor
protocol EditorPlayScenarioHost: AnyObject {
    /// Suspends until the host clock reaches `time` seconds since the scenario began.
    func wait(until time: Double) async throws
    func perform(_ input: EditorPlayScenario.Input)
    /// Waits for a frame completed after the call and reads it, downscaled to `maxDimension`.
    func captureFrame(camera: String?, maxDimension: Int) async throws -> EditorScenarioFrame
    func snapshot(watch: EditorPlayScenario.Watch) -> [String: Any]
    /// Script/runtime errors and prints since the last call.
    func drainLogs() -> [[String: Any]]
    /// Fatal script diagnostics (compilation or VM errors).
    var diagnostics: [String] { get }
}

/// Plays a scenario against a host and gathers frames, state and logs for the agent.
@MainActor
struct EditorPlayScenarioRunner {
    /// Extra wall-clock time beyond the scenario length for frame readback and snapshots.
    static let graceSeconds = 15.0
    static let maxLogEntries = 150

    let host: any EditorPlayScenarioHost
    /// Persists a PNG and returns its path, or throws.
    let saveFrame: @MainActor (Image, _ label: String) throws -> String
    var now: @MainActor () -> Date = Date.init

    func run(_ scenario: EditorPlayScenario) async -> [String: Any] {
        let started = now()
        let deadline = scenario.duration + Self.graceSeconds
        var frames: [[String: Any]] = []
        var snapshots: [[String: Any]] = []
        var inputs = 0
        var errors: [String] = []
        var status = "completed"

        func elapsed() -> Double { now().timeIntervalSince(started) }

        events: for event in scenario.events {
            do {
                try await host.wait(until: event.time)
            } catch {
                status = error is CancellationError ? "cancelled" : "failed"
                errors.append(error.localizedDescription)
                break events
            }
            if elapsed() > deadline {
                status = "timed_out"
                errors.append("Scenario exceeded its wall-clock limit of \(Int(deadline))s; later steps were skipped.")
                break events
            }
            switch event.action {
            case let .input(input):
                host.perform(input)
                inputs += 1
            case let .capture(label, camera):
                frames.append(await capture(label: label, camera: camera, at: event.time, scenario: scenario))
            case let .snapshot(label):
                snapshots.append(snapshot(label: label, at: event.time, watch: scenario.watch))
            }
        }

        if status == "completed" {
            do { try await host.wait(until: scenario.duration) } catch {
                status = error is CancellationError ? "cancelled" : "failed"
                errors.append(error.localizedDescription)
            }
        }
        snapshots.append(snapshot(label: "final", at: scenario.duration, watch: scenario.watch))

        let logs = host.drainLogs()
        let scriptErrors = logs.filter { ($0["level"] as? String).map { ["error", "critical"].contains($0) } == true }
        let failedFrames = frames.filter { $0["error"] != nil }
        var result: [String: Any] = [
            "status": status,
            "target": scenario.target.rawValue,
            "durationSeconds": scenario.duration,
            "elapsedSeconds": (elapsed() * 100).rounded() / 100,
            "inputEventsSent": inputs,
            "frames": frames,
            "snapshots": snapshots,
            "logs": Array(logs.suffix(Self.maxLogEntries)),
            "diagnostics": host.diagnostics,
            "errors": errors,
            "scriptErrorCount": scriptErrors.count + host.diagnostics.count,
            "verification": [
                "framesRendered": !frames.isEmpty && failedFrames.isEmpty,
                "stateRead": true,
                "evidence": "Frames are completed GPU frames of the game camera; snapshots are read from the live game world. Compare frames and snapshot values across times to prove behavior.",
            ],
        ]
        if !failedFrames.isEmpty {
            result["manualChecks"] = failedFrames.map { "Frame '\($0["label"] ?? "?")' unavailable: \($0["error"] ?? "unknown")" }
        }
        return result
    }

    private func capture(label: String, camera: String?, at time: Double, scenario: EditorPlayScenario) async -> [String: Any] {
        var entry: [String: Any] = ["label": label, "t": time]
        do {
            let frame = try await host.captureFrame(camera: camera, maxDimension: scenario.maxDimension)
            entry["path"] = try saveFrame(frame.image, label)
            entry["width"] = frame.image.width
            entry["height"] = frame.image.height
            entry["sourceWidth"] = frame.sourceWidth
            entry["sourceHeight"] = frame.sourceHeight
            entry["frameSequence"] = frame.sequence
            entry["activeCameras"] = frame.activeCameras
            let statistics = EditorFrameStatistics(frame.image)
            entry["meanRGB"] = statistics.mean
            entry["uniform"] = statistics.isUniform
            if statistics.isUniform {
                entry["warning"] = "The frame is a single flat color: the scene may be empty, fully culled, or not rendered yet. Do not treat it as proof."
            }
        } catch {
            entry["error"] = error.localizedDescription
        }
        return entry
    }

    private func snapshot(label: String, at time: Double, watch: EditorPlayScenario.Watch) -> [String: Any] {
        var value = host.snapshot(watch: watch)
        value["label"] = label
        value["t"] = time
        return value
    }
}


/// Cheap pixel statistics so a blank or flat frame is flagged without the agent guessing from a path.
struct EditorFrameStatistics {
    /// Mean red, green and blue on a 0...255 scale (rounded to one decimal).
    let mean: [Double]
    /// `true` when sampled pixels differ by less than a few levels in every channel.
    let isUniform: Bool

    init(_ image: Image) {
        let stride: Int
        switch image.format {
        case .rgba8, .bgra8, .bgra8_sRGB: stride = 4
        case .rgb8: stride = 3
        case .gray: stride = 1
        }
        let pixelCount = image.width * image.height
        guard pixelCount > 0, image.data.count >= pixelCount * stride else {
            mean = [0, 0, 0]
            isUniform = true
            return
        }
        let step = max(1, pixelCount / 4096)
        var sums = [Double](repeating: 0, count: 3)
        var low = [UInt8](repeating: 255, count: 3)
        var high = [UInt8](repeating: 0, count: 3)
        var samples = 0.0
        let bytes = [UInt8](image.data)
        var index = 0
        while index < pixelCount {
            let base = index * stride
            for channel in 0..<3 {
                // BGRA stores blue first; report RGB in a fixed order.
                let source = stride >= 3 ? (image.format == .rgba8 || image.format == .rgb8 ? channel : 2 - channel) : 0
                let value = bytes[base + source]
                sums[channel] += Double(value)
                low[channel] = min(low[channel], value)
                high[channel] = max(high[channel], value)
            }
            samples += 1
            index += step
        }
        mean = sums.map { ($0 / samples * 10).rounded() / 10 }
        isUniform = (0..<3).allSatisfy { high[$0] &- low[$0] < 3 }
    }
}
