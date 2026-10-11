import Testing

@testable import AdaEditor

struct EditorVRImmersionModeTests {
    @Test("Ordinary Enter always selects Full, including after a Mixed session")
    func fullAfterMixed() {
        var state = EditorVRImmersionState()
        #expect(state.mode == .full)
        state.request(.mixed, allowed: true)
        #expect(state.mode.preservesPassthrough)
        #expect(state.requestsEntry)
        state.finishEntryAttempt()
        state.request(allowed: true)
        #expect(state.mode == .full)
        #expect(!state.mode.preservesPassthrough)
        #expect(state.requestsEntry)
    }

    @Test("Mixed is explicit and another request cannot change a pending entry")
    func explicitAndPending() {
        var state = EditorVRImmersionState()
        state.request(allowed: true)
        state.request(.mixed, allowed: true)
        #expect(state.mode == .full)
        state.finishEntryAttempt()
        state.request(.mixed, allowed: true)
        #expect(state.mode == .mixed)
        state.finishEntryAttempt()
        #expect(!state.requestsEntry)
    }

    @Test("Unavailable entry never changes the chosen mode or opens a space")
    func unavailable() {
        var state = EditorVRImmersionState()
        state.request(.mixed, allowed: false)
        #expect(state.mode == .full)
        #expect(!state.requestsEntry)
    }
}
