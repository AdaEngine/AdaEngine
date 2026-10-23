//
//  PhysicsSimulationThreading.swift
//  AdaEngine
//
//

import AdaECS
import Foundation

public struct PhysicsSimulationThreading: Resource, Codable, Sendable {
    public var workerCount: Int
    public var box2DWorkerCount: Int
    public var box3DWorkerCount: Int

    public init(
        workerCount: Int = Self.recommendedWorkerCount,
        box2DWorkerCount: Int? = nil,
        box3DWorkerCount: Int? = nil
    ) {
        let normalizedWorkerCount = max(1, workerCount)
        self.workerCount = normalizedWorkerCount
        self.box2DWorkerCount = max(1, box2DWorkerCount ?? normalizedWorkerCount)
        self.box3DWorkerCount = max(1, box3DWorkerCount ?? normalizedWorkerCount)
    }

    public static var recommendedWorkerCount: Int {
        #if WASM
            return 1
        #else
            let coreCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
            return max(1, min(8, coreCount / 2))
        #endif
    }
}
