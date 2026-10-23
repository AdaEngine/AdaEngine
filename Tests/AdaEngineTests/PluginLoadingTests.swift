import AdaApp
import AdaECS
import Foundation
import Testing

@MainActor @Suite("Asynchronous plugin loading", .serialized)
struct PluginLoadingTests {
    @MainActor private final class State { var ready = false; var finished = false }
    private struct Loading: Plugin {
        let state: State
        func setup(in app: borrowing AppWorlds) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(10))
                state.ready = true
            }
        }
        func isLoaded(in app: borrowing AppWorlds) -> Bool { state.ready }
        func finish(for app: borrowing AppWorlds) { state.finished = true }
    }
    private struct Pending: Plugin {
        func setup(in app: borrowing AppWorlds) {}
        func isLoaded(in app: borrowing AppWorlds) -> Bool { false }
    }

    @Test func readinessAllowsTheNextPluginToStart() async throws {
        let state = State()
        let app = AppWorlds(main: World())
        app.addPlugin(Loading(state: state))
        try await app.build()
        #expect(state.ready && state.finished)
    }

    @Test func cancellationStopsWaitingForAnUnfinishedPlugin() async throws {
        let app = AppWorlds(main: World())
        app.addPlugin(Pending())
        let task = Task { try await app.build() }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
