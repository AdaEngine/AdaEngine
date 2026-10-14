import AdaEngine
import AdaMCPCore
import Foundation
import MCP

struct EditorPerformanceStatistics: Sendable {
    let count: Int
    let meanMs: Double
    let p95Ms: Double
    let maxMs: Double
    let totalMs: Double
    let sampledPercentile: Bool
}

struct EditorPerformanceHotspot: Sendable {
    let name: String
    let statistics: EditorPerformanceStatistics
}

struct EditorPerformanceSample: Sendable {
    let timestamp: Double
    let updatesPerSecond: Double?
    let update: EditorPerformanceStatistics?
    let processMemoryBytes: Int?
    let entityCount: Int?
    let systems: [EditorPerformanceHotspot]
    let renderNodes: [EditorPerformanceHotspot]
}

struct EditorPerformanceTarget: Identifiable, Sendable {
    let id: String
    let title: String
    var isRunning: Bool
    var samples: [EditorPerformanceSample]
}

final class EditorPerformanceSubscription: Sendable {}

@MainActor
final class EditorPerformanceStore: Sendable {
    private let profiler: AdaMCPProfiler
    private var targets: [String: EditorPerformanceTarget] = [:]
    private var targetOrder: [String] = []

    init(profiler: AdaMCPProfiler) {
        self.profiler = profiler
    }

    var sessions: [EditorPerformanceTarget] {
        targetOrder.compactMap { targets[$0] }
    }

    func register(title: String) -> String {
        let id = UUID().uuidString.lowercased()
        targets[id] = EditorPerformanceTarget(id: id, title: title, isRunning: true, samples: [])
        targetOrder.append(id)
        if targetOrder.count > 8 {
            targets[targetOrder.removeFirst()] = nil
        }
        return id
    }

    func target(_ id: String) -> EditorPerformanceTarget? {
        targets[id]
    }

    func subscribe(targetID: String) throws -> EditorPerformanceSubscription {
        guard targets[targetID] != nil else {
            throw EditorPerformanceError.targetNotFound(targetID)
        }
        return EditorPerformanceSubscription()
    }

    func refresh(targetID: String) throws {
        guard var target = targets[targetID], target.isRunning else {
            return
        }
        let payload = try profiler.liveSnapshotPayload()
        target.samples.append(Self.sample(from: payload))
        target.samples = Array(target.samples.suffix(240))
        targets[targetID] = target
    }

    func stopTarget(_ id: String) throws {
        guard var target = targets[id] else {
            throw EditorPerformanceError.targetNotFound(id)
        }
        let captureList = try profiler.captureListPayload().objectValue
        if captureList?["activeCapture"] != .null {
            _ = try profiler.stopCapture(arguments: [:])
        }
        target.isRunning = false
        targets[id] = target
    }

    private static func sample(from payload: Value) -> EditorPerformanceSample {
        let object = payload.objectValue
        let summary = object?["summary"]?.objectValue
        let frameCount = summary?["frameCount"]?.intValue ?? 0
        return EditorPerformanceSample(
            timestamp: Date.timeIntervalSinceReferenceDate,
            updatesPerSecond: summary?["fps"]?.doubleValue,
            update: statistics(from: summary?["frameTime"], count: frameCount),
            processMemoryBytes: object?["memory"]?.objectValue?["residentBytes"]?.intValue,
            entityCount: nil,
            systems: hotspots(from: summary?["systemHotspots"]),
            renderNodes: hotspots(from: summary?["renderNodeHotspots"])
        )
    }

    private static func hotspots(from value: Value?) -> [EditorPerformanceHotspot] {
        value?.arrayValue?.compactMap { value in
            guard let row = value.objectValue, let name = row["name"]?.stringValue else {
                return nil
            }
            return EditorPerformanceHotspot(
                name: name,
                statistics: statistics(from: value, count: row["count"]?.intValue ?? 0)
                    ?? EditorPerformanceStatistics(count: 0, meanMs: 0, p95Ms: 0, maxMs: 0, totalMs: 0, sampledPercentile: false)
            )
        } ?? []
    }

    private static func statistics(from value: Value?, count: Int) -> EditorPerformanceStatistics? {
        guard let object = value?.objectValue else {
            return nil
        }
        let mean = object["meanMs"]?.doubleValue ?? 0
        return EditorPerformanceStatistics(
            count: count,
            meanMs: mean,
            p95Ms: object["p95Ms"]?.doubleValue ?? 0,
            maxMs: object["maxMs"]?.doubleValue ?? 0,
            totalMs: object["totalMs"]?.doubleValue ?? mean * Double(count),
            sampledPercentile: false
        )
    }
}

struct EditorProfilerResource: AdaEngine.Resource {
    let profiler: AdaMCPProfiler
    let performance: EditorPerformanceStore

    @MainActor
    init(profiler: AdaMCPProfiler) {
        self.profiler = profiler
        self.performance = EditorPerformanceStore(profiler: profiler)
    }
}

@MainActor
struct EditorPerformancePlugin: AdaEngine.Plugin {
    let resource: EditorProfilerResource

    func setup(in app: borrowing AppWorlds) {
        app.insertResource(resource)
    }
}

private enum EditorPerformanceError: LocalizedError {
    case targetNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .targetNotFound(id): "Performance target '\(id)' was not found."
        }
    }
}
