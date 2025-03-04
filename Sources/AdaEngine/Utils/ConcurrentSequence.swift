//
//  ConcurrentSequence.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/30/24.
//

public struct ConcurrentSequence<S: Sequence> {

    public typealias Element = S.Element

    private let base: S

    init(base: S) {
        self.base = base
    }
}

public extension Sequence {
    /// Create wrapper for sequence to use Swift Modern Concurrency.
    var concurrent: ConcurrentSequence<Self> {
        return ConcurrentSequence(base: self)
    }
}

public extension ConcurrentSequence {
    /// Iterate over all elements in sequence and create task for each.
    func forEach(
        _ operation: @escaping @Sendable (Element) async -> Void
    ) async {
        // A task group automatically waits for all of its
        // sub-tasks to complete, while also performing those
        // tasks in parallel:
        await withTaskGroup(of: Void.self) { group in
            for element in self.base {
                group.addTask {
                    await operation(element)
                }
            }
        }
    }
}
