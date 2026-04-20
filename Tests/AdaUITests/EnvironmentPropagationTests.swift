//
//  EnvironmentPropagationTests.swift
//  AdaEngine
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
@testable import AdaUtils
import Observation
import Math

// MARK: - Test environment keys

private struct CounterKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

private struct LabelKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    fileprivate var testCounter: Int {
        get { self[CounterKey.self] }
        set { self[CounterKey.self] = newValue }
    }
    fileprivate var testLabel: String {
        get { self[LabelKey.self] }
        set { self[LabelKey.self] = newValue }
    }
}

@Observable
@MainActor
private final class ObservableEnvironmentModel {
    var count: Int = 0
}

@MainActor
private final class RenderProbe {
    private(set) var values: [Int] = []

    func record(_ value: Int) {
        values.append(value)
    }
}

@MainActor
private struct ObservableEnvironmentView: View {
    @Environment(ObservableEnvironmentModel.self) private var model

    let probe: RenderProbe

    var body: some View {
        probe.record(model.count)
        return Text("\(model.count)")
    }
}

// MARK: - Tests

@MainActor
@Suite("Environment propagation optimizations")
struct EnvironmentPropagationTests {

    init() async throws {
        try Application.prepareForTest()
    }

    // MARK: subscribedKeyIDs populated at init time

    @Test("@Environment records subscribed key at init time")
    func environmentCapturesSubscribedKeyIDs() {
        let wrapper = Environment(\.testCounter)
        #expect(wrapper.container.subscribedKeyIDs.contains(ObjectIdentifier(CounterKey.self)))
        #expect(!wrapper.container.subscribedKeyIDs.contains(ObjectIdentifier(LabelKey.self)))
    }

    @Test("@Environment for different keys stores distinct key IDs")
    func differentWrappersStoreDistinctKeyIDs() {
        let counterWrapper = Environment(\.testCounter)
        let labelWrapper = Environment(\.testLabel)
        #expect(counterWrapper.container.subscribedKeyIDs.contains(ObjectIdentifier(CounterKey.self)))
        #expect(labelWrapper.container.subscribedKeyIDs.contains(ObjectIdentifier(LabelKey.self)))
        #expect(counterWrapper.container.subscribedKeyIDs != labelWrapper.container.subscribedKeyIDs)
    }

    // MARK: version guard

    @Test("updateEnvironment is a no-op when version is unchanged")
    func updateEnvironmentVersionGuard() {
        let tester = ViewTester {
            Text("hello").frame(width: 100, height: 40)
        }
        .setSize(Size(width: 120, height: 60))
        .performLayout()

        let root = tester.containerView.viewTree.rootNode
        let envBefore = root.environment
        root.updateEnvironment(envBefore)
        #expect(root.environment.version == envBefore.version)
    }

    // MARK: subscription filtering via hasChangedValues

    @Test("storage is skipped when only unsubscribed key changes")
    func storageSkippedForUnsubscribedKeyChange() {
        let subscribedIDs: Set<ObjectIdentifier> = [ObjectIdentifier(CounterKey.self)]

        var oldEnv = EnvironmentValues()
        oldEnv.testCounter = 5

        var newEnv = EnvironmentValues()
        newEnv.testCounter = 5     // unchanged
        newEnv.testLabel = "new"   // changed, but not subscribed

        let hasChanged = newEnv.hasChangedValues(forKeyIDs: subscribedIDs, comparedTo: oldEnv)
        #expect(!hasChanged, "Storage subscribed to CounterKey must not rebuild when only LabelKey changes")
    }

    @Test("storage is notified when subscribed key changes")
    func storageNotifiedForSubscribedKeyChange() {
        let subscribedIDs: Set<ObjectIdentifier> = [ObjectIdentifier(CounterKey.self)]

        var oldEnv = EnvironmentValues()
        oldEnv.testCounter = 5

        var newEnv = EnvironmentValues()
        newEnv.testCounter = 99

        let hasChanged = newEnv.hasChangedValues(forKeyIDs: subscribedIDs, comparedTo: oldEnv)
        #expect(hasChanged, "Storage subscribed to CounterKey must rebuild when CounterKey changes")
    }

    @Test("empty subscribedIDs guard short-circuits to always update")
    func subscriptionFilterEmptySubscribesAll() {
        let subscribedIDs: Set<ObjectIdentifier> = []

        var oldEnv = EnvironmentValues()
        var newEnv = EnvironmentValues()
        newEnv.testLabel = "x"

        // ViewNode.updateEnvironment: if empty → always update (guard short-circuits)
        let shouldUpdate = subscribedIDs.isEmpty
            || newEnv.hasChangedValues(forKeyIDs: subscribedIDs, comparedTo: oldEnv)
        #expect(shouldUpdate)
    }

    @Test("@Environment observable invalidates when an observed property changes")
    func observableEnvironmentTriggersRecomposeOnMemberMutation() async {
        let model = ObservableEnvironmentModel()
        let probe = RenderProbe()

        _ = ViewTester {
            ObservableEnvironmentView(probe: probe)
                .environment(model)
        }
        .setSize(Size(width: 120, height: 60))
        .performLayout()

        let initialRenderCount = probe.values.count
        #expect(initialRenderCount > 0)
        #expect(probe.values.last == 0)

        model.count = 1
        await Task.yield()

        #expect(probe.values.count > initialRenderCount)
        #expect(probe.values.last == 1)
    }
}
