//
//  RenderPipelines.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.12.2025.
//

import AdaECS

public protocol RenderPipelineConfigurator: Resource {
    associatedtype Configuration: Hashable, Sendable

    func configurate(with configuration: Configuration) -> RenderPipelineDescriptor
}

public struct RenderPipelineEmptyConfiguration: Hashable, Sendable {
    @usableFromInline
    init() {}
}

public struct RenderPipelines<T: RenderPipelineConfigurator>: Resource {
    @usableFromInline
    var caches: [T.Configuration: RenderPipeline] = [:]

    @usableFromInline
    let configurator: T

    @usableFromInline
    var lastConfiguration: T.Configuration?

    @usableFromInline
    var lastPipeline: (any RenderPipeline)?

    public init(configurator: T) {
        self.configurator = configurator
    }

    public mutating func pipeline(
        for configuration: T.Configuration,
        device: RenderDevice
    ) -> any RenderPipeline {
        // Consecutive mesh draws usually share a layout. Equality can reuse the
        // descriptor's array storage without hashing every attribute name again.
        if lastConfiguration == configuration, let lastPipeline {
            return lastPipeline
        }
        if let pipeline = self.caches[configuration] {
            lastConfiguration = configuration
            lastPipeline = pipeline
            return pipeline
        }

        let pipelineDesc = configurator.configurate(with: configuration)
        let pipeline = device.createRenderPipeline(from: pipelineDesc)
        caches[configuration] = pipeline
        lastConfiguration = configuration
        lastPipeline = pipeline
        return pipeline
    }

    @inlinable
    public mutating func dropCache() {
        self.caches.removeAll(keepingCapacity: true)
        lastConfiguration = nil
        lastPipeline = nil
    }
}

extension RenderPipelines where T.Configuration == RenderPipelineEmptyConfiguration {
    @inlinable
    public mutating func pipeline(
        device: RenderDevice
    ) -> any RenderPipeline {
        self.pipeline(for: RenderPipelineEmptyConfiguration(), device: device)
    }
}

extension RenderPipelines: WorldInitable where T: WorldInitable {
    @inlinable
    public init(from world: World) {
        self.configurator = T(from: world)
    }
}
