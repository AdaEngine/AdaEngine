//
//  ViewStoragesTests.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform

@MainActor
struct ViewStoragesTests {

    init() async throws {
        try Application.prepareForTest()
    }

    /// Verifies `@State` survives node updates and explicit recompose.
    ///
    /// Why this test exists:
    /// `ViewNode.update(from:)` replaces `content` and rebinds storages.
    /// If state storage is kept weakly, old content deallocation drops the only
    /// strong reference and state is recreated from its initial value.
    ///
    /// Regression protected:
    /// - old `StateStorage` is not strongly retained by `ViewStateContainer`;
    /// - rebind by the same storage key recreates storage from initial value.
    @Test
    func stateStorage_isRetainedAcrossRecompose() {
        let container = ViewStateContainer()

        let firstState = State(wrappedValue: 0)
        firstState.bind(to: container, key: "_value")
        firstState.wrappedValue = 42

        let reboundState = State(wrappedValue: 0)
        reboundState.bind(to: container, key: "_value")

        #expect(reboundState.wrappedValue == 42)
    }
}
