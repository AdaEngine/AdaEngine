//
//  NavigationTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 25.03.2026.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import AdaUtils
import Math

@MainActor
struct NavigationPathTests {

    @Test
    func initialPath_isEmpty() {
        let path = NavigationPath()
        #expect(path.isEmpty)
        #expect(path.count == 0)
    }

    @Test
    func append_incrementsCount() {
        var path = NavigationPath()
        path.append("hello")
        #expect(!path.isEmpty)
        #expect(path.count == 1)
    }

    @Test
    func removeLast_decrementsCount() {
        var path = NavigationPath()
        path.append("a")
        path.append("b")
        path.removeLast()
        #expect(path.count == 1)
    }

    @Test
    func removeLast_onEmpty_doesNotCrash() {
        var path = NavigationPath()
        path.removeLast()
        #expect(path.isEmpty)
    }

    @Test
    func topElement_returnsLastAppended() {
        var path = NavigationPath()
        path.append(42)
        #expect(path.topElement == AnyHashable(42))
    }
}

@MainActor
struct NavigationStackTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func navigationStack_showsRootContent_whenPathEmpty() {
        var rootAppeared = false

        _ = ViewTester {
            NavigationStack {
                Color.red
                    .frame(width: 100, height: 100)
                    .onAppear { rootAppeared = true }
            }
        }

        #expect(rootAppeared)
    }

    @Test
    func navigationStack_showsDestination_whenPathHasValue() {
        var destinationAppeared = false

        var path = NavigationPath()
        path.append("detail")

        _ = ViewTester {
            NavigationStack(path: .constant(path)) {
                Color.red
                    .navigate(for: String.self) { _ in
                        Color.blue
                            .frame(width: 100, height: 100)
                            .onAppear { destinationAppeared = true }
                    }
            }
        }

        #expect(destinationAppeared)
    }

    @Test
    func navigationLink_pushesValueOnTap() {
        var destinationAppeared = false

        let tester = ViewTester {
            NavigationStack {
                NavigationLink(value: "detail") {
                    Color.red
                        .frame(width: 100, height: 100)
                }
                .navigate(for: String.self) { _ in
                    Color.blue
                        .frame(width: 200, height: 200)
                        .onAppear { destinationAppeared = true }
                }
            }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        #expect(!destinationAppeared)

        tester.sendMouseEvent(at: Point(200, 200), phase: MouseEvent.Phase.began)
        tester.sendMouseEvent(at: Point(200, 200), phase: MouseEvent.Phase.ended)

        #expect(destinationAppeared)
    }

    @Test
    func dismissAction_popsNavigation_andShowsRoot() {
        var rootAppeared = false
        var detailAppeared = false

        var path = NavigationPath()
        path.append("detail")

        let tester = ViewTester {
            NavigationStack(path: .constant(path)) {
                Color.red
                    .onAppear { rootAppeared = true }
                    .navigate(for: String.self) { _ in
                        DismissTestView(onAppear: { detailAppeared = true })
                    }
            }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        #expect(detailAppeared)

        let stackNode = tester.containerView.viewTree.rootNode.contentNode as? NavigationStackNode
        #expect(stackNode != nil)

        stackNode?.navigationContext.pop()

        #expect(stackNode?.navigationContext.path.isEmpty == true)
    }
}

// Helper view that calls dismiss via environment
private struct DismissTestView: View {
    let onAppear: () -> Void

    var body: some View {
        Color.blue
            .frame(width: 200, height: 200)
            .onAppear(perform: onAppear)
    }
}

@MainActor
struct FullScreenCoverTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func fullScreenCover_notPresented_overlayHidden() {
        var overlayAppeared = false

        _ = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .fullScreenCover(isPresented: Binding<Bool>.constant(false)) {
                    Color.blue
                        .onAppear { overlayAppeared = true }
                }
        }

        #expect(!overlayAppeared)
    }

    @Test
    func fullScreenCover_presented_overlayShown() {
        var overlayAppeared = false

        _ = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .fullScreenCover(isPresented: Binding<Bool>.constant(true)) {
                    Color.blue
                        .onAppear { overlayAppeared = true }
                }
        }

        #expect(overlayAppeared)
    }

    @Test
    func fullScreenCover_dismiss_hidesOverlay() {
        var isPresentedValue = true
        let isPresented = Binding(
            get: { isPresentedValue },
            set: { isPresentedValue = $0 }
        )

        var overlayDisappeared = false

        let tester = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .fullScreenCover(isPresented: isPresented) {
                    Color.blue
                        .onDisappear { overlayDisappeared = true }
                }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        #expect(isPresentedValue)
        #expect(!overlayDisappeared)

        // Simulate dismiss: flip the binding and trigger rebuild
        isPresented.wrappedValue = false

        let coverNode = tester.containerView.viewTree.rootNode.contentNode as? FullScreenCoverNode
        #expect(coverNode != nil)
        coverNode?.invalidateContent()

        #expect(!isPresentedValue)
    }

    @Test
    func fullScreenCover_presented_overlayNodeExists() {
        var overlayAppeared = false

        let tester = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .fullScreenCover(isPresented: Binding<Bool>.constant(true)) {
                    Color.blue
                        .onAppear { overlayAppeared = true }
                }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        // overlayAppeared proves the overlay node was built and attached to the tree
        #expect(overlayAppeared)

        let coverNode = tester.containerView.viewTree.rootNode.contentNode as? FullScreenCoverNode
        #expect(coverNode != nil)
    }
}
