//
//  FixedTimestepTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.02.2025.
//

import XCTest
@_spi(Internal) @testable import AdaEngine

final class FixedTimestepTests: XCTestCase {
    func testInitialization() {
        let stepsPerSecond: Float = 1.0 / 60.0
        let timestep = FixedTimestep(stepsPerSecond: 60)
        XCTAssertEqual(timestep.step, Float(stepsPerSecond))
        XCTAssertEqual(timestep.accumulator, 0)
    }
    
    func testAccumulation() {
        let stepsPerSecond: Float = 1 / 60
        let timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: stepsPerSecond / 2)
        XCTAssertFalse(result.isFixedTick)
        
        let result2 = timestep.advance(with: stepsPerSecond / 2)
        XCTAssertTrue(result2.isFixedTick)
    }
    
    func testMultipleTicks() {
        let stepsPerSecond: Float = 1.0 / 60.0
        let timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: stepsPerSecond * 3)
        XCTAssertTrue(result.isFixedTick)
        XCTAssertLessThan(timestep.accumulator, stepsPerSecond)
    }
    
    func testMaxAccumulation() {
        let stepsPerSecond: Float = 1.0 / 60.0
        let timestep = FixedTimestep(stepsPerSecond: 60)
        
        let result = timestep.advance(with: TimeInterval(stepsPerSecond * 20))
        
        XCTAssertTrue(result.isFixedTick)
        XCTAssertLessThanOrEqual(timestep.accumulator, stepsPerSecond * 5)
    }
}
