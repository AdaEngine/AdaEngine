//
//  ViewStoragesTests.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

import Testing
import AdaUtils
import Observation
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

    @Test
    func observedDetachedContainer_isNotRetainedByObservationCallback() {
        let model = ObservationRetentionModel()
        weak var weakNode: ViewNode?

        do {
            let view = ObservationRetentionView(model: model)
            let inputs = _ViewInputs(parentNode: nil, environment: EnvironmentValues())
            let output = ObservationRetentionView._makeView(
                _ViewGraphNode(value: view),
                inputs: inputs
            )
            weakNode = output.node
        }

        #expect(weakNode == nil)
    }
}

@Observable
private final class ObservationRetentionModel {
    var counter = 0
}

private struct ObservationRetentionView: View {
    let model: ObservationRetentionModel

    var body: some View {
        let _ = model.counter
        EmptyView()
    }
}
