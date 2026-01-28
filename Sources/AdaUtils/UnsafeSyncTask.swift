import Dispatch

/// Use Swift Coroutines but block current execution context and wait until task is done.
public final class UnsafeTask<T>: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<T, Error>?

    public init(priority: TaskPriority = .userInitiated, block: @escaping @Sendable () async throws -> T) {
        Task.detached(priority: priority) { @Sendable [self, semaphore] in
            do {
                self.result = .success(try await block())
            } catch {
                self.result = .failure(error)
            }
            semaphore.signal()
        }
    }

    public func get() throws -> T {
        if let result = result {
            return try result.get()
        }

        semaphore.wait()
        return try result!.get()
    }
}
