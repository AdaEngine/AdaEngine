//
//  FixedTimestepTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

import Testing
@_spi(Internal) @testable import AdaUtils

struct FixedTimestepTests {
    @Test
    func initialization() {
        let stepsPerSecond: Float = 1.0 / 60.0
        let timestep = FixedTimestep(stepsPerSecond: 60)
        #expect(timestep.step == Float(stepsPerSecond))
        #expect(timestep.accumulator == 0)
    }
    
    @Test
    func accumulation() {
        let stepsPerSecond: Float = 1 / 60
        var timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: stepsPerSecond / 2)
        #expect(result.isFixedTick == false)
        
        let result2 = timestep.advance(with: stepsPerSecond / 2)
        #expect(result2.isFixedTick)
    }
    
    @Test
    func multipleTicks() {
        let stepsPerSecond: Float = 1.0 / 60.0
        var timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: stepsPerSecond * 3)
        #expect(result.isFixedTick)
        #expect(timestep.accumulator < stepsPerSecond)
    }
    
    @Test
    func maxAccumulation() {
        let stepsPerSecond: Float = 1.0 / 60.0
        var timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: TimeInterval(stepsPerSecond * 20))
        
        #expect(result.isFixedTick)
        #expect(timestep.accumulator <= stepsPerSecond * 5)
    }
}
