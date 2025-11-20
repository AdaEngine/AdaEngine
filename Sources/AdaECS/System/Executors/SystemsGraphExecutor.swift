//
//  SystemsGraphExecutor.swift
//  AdaEngine
//

import AdaUtils
import Collections

protocol SystemsGraphExecutor: Sendable {

    mutating func initialize(_ graph: borrowing SystemsGraph)

    mutating func execute(
        _ graph: borrowing SystemsGraph,
        world: World,
        scheduler: SchedulerName
    ) async
}