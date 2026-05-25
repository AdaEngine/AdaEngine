//
//  ViewVisibilityTests.swift
//
//
//  Created by vladislav.prusakov on 11.08.2024.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import AdaUtils
import Math

@MainActor
struct ViewVisibilityTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func onAppear_calledWhenViewAddedToTree() async {
        var appeared = false
        _ = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appeared = true }
        }
        await flushLifecycleActions()
        #expect(appeared)
    }

    @Test
    func onAppear_calledOnce_onMultipleLayouts() async {
        var count = 0
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { count += 1 }
        }
        await flushLifecycleActions()
        tester.performLayout()
        tester.performLayout()
        #expect(count == 1)
    }

    @Test
    func onDisappear_calledWhenNodeDetachedFromTree() async {
        var disappeared = false
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onDisappear { disappeared = true }
        }
        await flushLifecycleActions()
        #expect(!disappeared)

        let contentNode = tester.containerView.viewTree.rootNode.contentNode
        contentNode.parent = nil
        await flushLifecycleActions()

        #expect(disappeared)
    }

    @Test
    func onDisappear_notCalled_whenNeverAppeared() {
        var disappeared = false
        let inputs = _ViewInputs(parentNode: nil, environment: EnvironmentValues())
        let colorView = Color.blue
        let contentNode = Color._makeView(_ViewGraphNode(value: colorView), inputs: inputs).node
        let node = VisibilityViewNode(contentNode: contentNode, content: colorView)
        node.onDisappear = { disappeared = true }

        node.parent = nil
        #expect(!disappeared)
    }

    @Test
    func onAppearAndOnDisappear_bothFire_forSameView() async {
        var appeared = false
        var disappeared = false

        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appeared = true }
                .onDisappear { disappeared = true }
        }
        await flushLifecycleActions()

        #expect(appeared)
        #expect(!disappeared)

        let contentNode = tester.containerView.viewTree.rootNode.contentNode
        contentNode.parent = nil
        await flushLifecycleActions()

        #expect(disappeared)
    }

    @Test
    func onAppear_firesAgain_onReInsertion() async {
        final class Model {
            var isVisible = true
        }

        let model = Model()
        var appearCount = 0
        var disappearCount = 0

        let tester = ViewTester(rootView: ConditionalVisibilityHost(
            isVisible: Binding(
                get: { model.isVisible },
                set: { model.isVisible = $0 }
            ),
            onAppear: { appearCount += 1 },
            onDisappear: { disappearCount += 1 }
        ))
        await flushLifecycleActions()

        #expect(appearCount == 1)
        #expect(disappearCount == 0)

        model.isVisible = false
        tester.invalidateContent()
        await flushLifecycleActions()

        #expect(disappearCount == 1)

        model.isVisible = true
        tester.invalidateContent()
        await flushLifecycleActions()

        #expect(appearCount == 2)
    }

    @Test
    func onDisappear_firesOnTabSwitch() async {
        final class Model {
            var selected: Int = 0
        }

        let model = Model()
        var tabAAppeared = false
        var tabADisappeared = false
        var tabBAppeared = false

        let tester = ViewTester {
            TabView(
                selection: Binding(
                    get: { model.selected },
                    set: { model.selected = $0 }
                )
            ) {
                Tab("", value: 0) {
                    Color.red
                        .frame(width: 100, height: 100)
                        .onAppear { tabAAppeared = true }
                        .onDisappear { tabADisappeared = true }
                }
                Tab("", value: 1) {
                    Color.blue
                        .frame(width: 100, height: 100)
                        .onAppear { tabBAppeared = true }
                }
            }
        }
        .setSize(Size(width: 400, height: 200))
        .performLayout()
        await flushLifecycleActions()

        #expect(tabAAppeared)
        #expect(!tabADisappeared)
        #expect(!tabBAppeared)

        model.selected = 1
        tester.invalidateContent()
        await flushLifecycleActions()

        #expect(tabADisappeared)
        #expect(tabBAppeared)
    }

    @Test
    func onAppear_stateMutationIsDeferredUntilAfterTreeAttachment() async {
        let recorder = LifecycleMutationRecorder()
        let tester = ViewTester(rootView: LifecycleStateMutationHost(recorder: recorder))

        #expect(recorder.appearCount == 0)
        #expect(recorder.value == 0)

        await flushLifecycleActions()
        tester.performLayout()

        #expect(recorder.appearCount == 1)
        #expect(recorder.value == 1)
    }

    @Test
    func onAppear_notCalledWhenDetachedBeforeLifecycleFlush() async {
        var appeared = false
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appeared = true }
        }

        tester.containerView.viewTree.rootNode.contentNode.parent = nil
        await flushLifecycleActions()

        #expect(!appeared)
    }

    @Test
    func onAppear_notCalledWhenAncestorDetachedBeforeLifecycleFlush() async {
        var appeared = false
        let tester = ViewTester {
            VStack {
                Color.blue
                    .frame(width: 50, height: 50)
                    .onAppear { appeared = true }
            }
        }

        tester.containerView.viewTree.rootNode.contentNode.parent = nil
        await flushLifecycleActions()

        #expect(!appeared)
    }
}

private func flushLifecycleActions() async {
    await Task.yield()
}

private final class LifecycleMutationRecorder {
    var appearCount = 0
    var value = 0
}

private struct LifecycleStateMutationHost: View {
    let recorder: LifecycleMutationRecorder

    @State private var value = 0

    var body: some View {
        let _ = recorder.value = value
        Text("\(value)")
            .onAppear {
                recorder.appearCount += 1
                value = 1
            }
    }
}

private struct ConditionalVisibilityHost: View {
    let isVisible: Binding<Bool>
    let onAppear: () -> Void
    let onDisappear: () -> Void

    var body: some View {
        if isVisible.wrappedValue {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear(perform: onAppear)
                .onDisappear(perform: onDisappear)
        } else {
            EmptyView()
        }
    }
}
