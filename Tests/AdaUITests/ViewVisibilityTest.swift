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
    func onAppear_calledWhenViewAddedToTree() {
        var appeared = false
        _ = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appeared = true }
        }
        #expect(appeared)
    }

    @Test
    func onAppear_calledOnce_onMultipleLayouts() {
        var count = 0
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { count += 1 }
        }
        tester.performLayout()
        tester.performLayout()
        #expect(count == 1)
    }

    @Test
    func onDisappear_calledWhenNodeDetachedFromTree() {
        var disappeared = false
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onDisappear { disappeared = true }
        }
        #expect(!disappeared)

        let contentNode = tester.containerView.viewTree.rootNode.contentNode
        contentNode.parent = nil

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
    func onAppearAndOnDisappear_bothFire_forSameView() {
        var appeared = false
        var disappeared = false

        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appeared = true }
                .onDisappear { disappeared = true }
        }

        #expect(appeared)
        #expect(!disappeared)

        let contentNode = tester.containerView.viewTree.rootNode.contentNode
        contentNode.parent = nil

        #expect(disappeared)
    }

    @Test
    func onAppear_firesAgain_onReInsertion() {
        var appearCount = 0
        var disappearCount = 0

        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear { appearCount += 1 }
                .onDisappear { disappearCount += 1 }
        }

        #expect(appearCount == 1)
        #expect(disappearCount == 0)

        let rootNode = tester.containerView.viewTree.rootNode
        let oldNode = rootNode.contentNode
        oldNode.parent = nil

        #expect(disappearCount == 1)

        // Simulate re-insertion with a fresh node (mimics TabContainer's rebuildAll)
        let inputs = _ViewInputs(parentNode: rootNode, environment: EnvironmentValues())
        let newContentView = Color.blue
            .frame(width: 50, height: 50)
            .onAppear { appearCount += 1 }
            .onDisappear { disappearCount += 1 }
        let newNode = type(of: newContentView)._makeView(
            _ViewGraphNode(value: newContentView),
            inputs: inputs
        ).node
        newNode.parent = rootNode
        tester.containerView.viewTree.setViewOwner(tester.containerView)

        #expect(appearCount == 2)
    }

    @Test
    func onDisappear_firesOnTabSwitch() {
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

        #expect(tabAAppeared)
        #expect(!tabADisappeared)
        #expect(!tabBAppeared)

        model.selected = 1
        tester.invalidateContent()

        #expect(tabADisappeared)
        #expect(tabBAppeared)
    }
}
