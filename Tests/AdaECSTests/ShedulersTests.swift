//
//  ShedulersTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 06.11.2025.
//

import AdaECS
import Testing

@Suite
struct SchedulersTests {
    @Test
    func `add system to existing schedule`() async throws {
        let world = World()
        world.addScheduler(.init(name: .test))
        world.insertResource(CheckSystemMarker(value: 0))
        world.addSystem(checkSystem.self, on: .test)

        await world.runScheduler(.test)

        let marker = try #require(world.getResource(CheckSystemMarker.self))
        #expect(marker.value == 1, "CheckSystem should exists for Tests scheduler")
    }

    @Test
    func `add system to non existing schedule`() async throws {
        let world = World()
        
        world.insertResource(CheckSystemMarker(value: 0))
        world.addSystem(checkSystem.self, on: .test)

        await world.runScheduler(.test)

        let marker = try #require(world.getResource(CheckSystemMarker.self))
        #expect(marker.value == 1, "CheckSystem should exists for Tests scheduler")
    }
}

struct CheckSystemMarker: Resource {
    var value: Int
}

@System
func check(_ res: ResMut<CheckSystemMarker>) {
    res.value += 1
    print(res.wrappedValue)
}

private extension SchedulerName {
    static let test: SchedulerName = "Tests"
}
