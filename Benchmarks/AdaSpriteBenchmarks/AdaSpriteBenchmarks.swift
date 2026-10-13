import AdaCorePipelines
import AdaECS
import AdaRender
import AdaSprite
import AdaTransform
import AdaUtils
import Benchmark
import Foundation
import Math

// MARK: - Constants

private enum BenchConstants {
    static let smoke = ProcessInfo.processInfo.environment["ADAENGINE_BENCHMARK_SMOKE"] == "1"
    static let fiftyThousand = smoke ? 500 : 50_000
    static let oneHundredThousand = smoke ? 1_000 : 100_000
}

// MARK: - Fixtures

/// A main world with `count` visible untextured sprites and a render world that extracts them.
private struct ExtractFixture {
    let mainWorld: World
    let renderWorld: World
    let count: Int
}

private func makeExtractFixture(spriteCount: Int) -> ExtractFixture {
    let mainWorld = World(name: "BenchMainWorld")
    for index in 0..<spriteCount {
        mainWorld.spawn {
            Sprite(tintColor: .red, size: Size(width: 16, height: 16))
            Transform(position: [Float(index % 1_000), Float(index / 1_000), Float(index % 7)])
        }
    }

    let renderWorld = World(name: "BenchRenderWorld")
    renderWorld.insertResource(MainWorld(world: mainWorld))
    renderWorld.insertResource(ExtractedSprites())
    renderWorld.addSystem(ExtractSpriteSystem.self, on: .extract)
    return ExtractFixture(mainWorld: mainWorld, renderWorld: renderWorld, count: spriteCount)
}

/// Keeps the main world alive: queries only hold an unowned reference to it.
private struct QueryOnlyState {
    let fixture: ExtractFixture
    let query: Query<Entity, Sprite, GlobalTransform, Transform, Visibility>
    let count: Int
}

private func extractedCount(in fixture: ExtractFixture) -> Int {
    fixture.renderWorld.getResource(ExtractedSprites.self)?.sprites.count ?? -1
}



// MARK: - PrepareSprites fixture

private struct PrepareFixture {
    let renderWorld: World
    let spriteCount: Int
    let cameraCount: Int
}

private func makePrepareFixture(spriteCount: Int, cameraCount: Int) async throws -> PrepareFixture {
    // The headless backend creates stub pipelines, so no GPU is needed to measure CPU-side preparation.
    if unsafe RenderEngine.shared == nil {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        try RenderEngine.setupRenderEngine()
    }
    await MainActor.run {
        Camera.registerComponent()
        VisibleEntities.registerComponent()
    }

    var sprites = SparseSet<Entity.ID, ExtractedSprite>()
    for id in 1...spriteCount {
        sprites[id] = ExtractedSprite(
            entityId: id,
            texture: nil,
            size: Size(width: 16, height: 16),
            flipX: false,
            flipY: false,
            tintColor: .white,
            transform: Transform(position: [Float(id % 1_000), Float(id / 1_000), 0]),
            worldTransform: Transform3D(translation: [Float(id % 1_000), Float(id / 1_000), Float(id % 7)])
        )
    }

    let renderWorld = World(name: "BenchPrepareWorld")
    renderWorld.insertResource(ExtractedSprites(sprites: sprites))
    renderWorld.insertResource(AdditionalExtractedSprites())
    renderWorld.insertResource(RenderItems<Transparent2DRenderItem>())
    renderWorld.insertResource(SpriteDrawPass())
    renderWorld.insertResource(RenderPipelines(configurator: SpriteRenderPipeline()))
    renderWorld.insertResource(RenderDeviceHandler(renderDevice: unsafe RenderEngine.shared.renderDevice))
    renderWorld.addSystem(PrepareSpritesSystem.self, on: .preUpdate)

    let visibleIds = Set(1...spriteCount)
    for _ in 0..<cameraCount {
        renderWorld.spawn {
            Camera()
            VisibleEntities(entityIds: visibleIds)
        }
    }
    return PrepareFixture(renderWorld: renderWorld, spriteCount: spriteCount, cameraCount: cameraCount)
}

private func renderItemCount(in fixture: PrepareFixture) -> Int {
    fixture.renderWorld.getResource(RenderItems<Transparent2DRenderItem>.self)?.items.count ?? -1
}

private func resetRenderItems(in fixture: PrepareFixture) {
    fixture.renderWorld.getRefResource(RenderItems<Transparent2DRenderItem>.self).wrappedValue.items.removeAll(keepingCapacity: true)
}

// MARK: - Benchmarks

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock, .cpuTotal, .mallocCountTotal, .retainCount, .releaseCount],
        warmupIterations: 2,
        scalingFactor: .one,
        maxDuration: BenchConstants.smoke ? .milliseconds(200) : .seconds(3),
        maxIterations: BenchConstants.smoke ? 3 : 50
    )

    // Full extract stage as the engine runs it: scheduler, system, Extract<Query>, SparseSet rebuild.
    for (label, count) in [("50k", BenchConstants.fiftyThousand), ("100k", BenchConstants.oneHundredThousand)] {
        Benchmark(
            "AdaSprite.ExtractSprite.\(label)",
            closure: { (benchmark: Benchmark, fixture: ExtractFixture) async in
                await fixture.renderWorld.runScheduler(.extract)
                benchmark.stopMeasurement()
                blackHole(fixture)
                precondition(extractedCount(in: fixture) == fixture.count, "Every visible sprite must be extracted")
            },
            setup: {
                let fixture = makeExtractFixture(spriteCount: count)
                // Warm the extraction once so the measured runs reuse SparseSet capacity.
                await fixture.renderWorld.runScheduler(.extract)
                precondition(extractedCount(in: fixture) == count, "Fixture must extract every sprite")
                return fixture
            }
        )

        // The same query without building ExtractedSprite values: separates iteration cost from rebuild cost.
        Benchmark(
            "AdaSprite.ExtractQueryOnly.\(label)",
            closure: { (benchmark: Benchmark, state: QueryOnlyState) in
                let query = state.query
                var visible = 0
                query.forEach { _, _, _, _, visibility in
                    if visibility != .hidden {
                        visible &+= 1
                    }
                }
                benchmark.stopMeasurement()
                blackHole(visible)
                precondition(visible == state.count)
            },
            setup: {
                let fixture = makeExtractFixture(spriteCount: count)
                let query = Query<Entity, Sprite, GlobalTransform, Transform, Visibility>(from: fixture.mainWorld)
                precondition(query.count == count, "Query must visit every fixture sprite")
                return QueryOnlyState(fixture: fixture, query: query, count: count)
            }
        )
    }


    // PrepareSprites emits one render item per visible sprite per camera. Items are reset outside the measurement.
    let prepareCases: [(label: String, sprites: Int, cameras: Int)] = [
        ("1cam.50k", BenchConstants.fiftyThousand, 1),
        ("2cam.50k", BenchConstants.fiftyThousand, 2),
        ("1cam.100k", BenchConstants.oneHundredThousand, 1),
    ]
    for prepareCase in prepareCases {
        Benchmark(
            "AdaSprite.PrepareSprites.\(prepareCase.label)",
            closure: { (benchmark: Benchmark, fixture: PrepareFixture) async in
                resetRenderItems(in: fixture)
                benchmark.startMeasurement()
                await fixture.renderWorld.runScheduler(.preUpdate)
                benchmark.stopMeasurement()
                precondition(
                    renderItemCount(in: fixture) == fixture.spriteCount * fixture.cameraCount,
                    "Every visible sprite must produce one render item per camera"
                )
            },
            setup: {
                let fixture = try await makePrepareFixture(spriteCount: prepareCase.sprites, cameraCount: prepareCase.cameras)
                await fixture.renderWorld.runScheduler(.preUpdate)
                precondition(renderItemCount(in: fixture) == prepareCase.sprites * prepareCase.cameras)
                return fixture
            }
        )
    }
}
