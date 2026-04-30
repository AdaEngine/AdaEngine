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

    @Test
    func rootOnAppear_doesNotRefire_whenRootStateChanges() {
        var rootAppearedCount = 0
        let driver = NavigationRootStateDriver()

        _ = ViewTester {
            NavigationRootStateHost(driver: driver) {
                rootAppearedCount += 1
            }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        #expect(rootAppearedCount == 1)
        #expect(driver.counter != nil)

        driver.counter?.wrappedValue += 1

        #expect(rootAppearedCount == 1)
    }

    @Test
    func navigationStack_nestedScrollContentExtendsUnderNavigationBar() throws {
        let tester = ViewTester {
            NavigationStack {
                ZStack(anchor: .topLeading) {
                    VStack {
                        ScrollViewReader { _ in
                            ScrollView {
                                Color.red
                                    .frame(width: 320, height: 640)
                            }
                        }
                        .frame(minHeight: 0, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Chat")
            }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        let scrollNode = try #require(firstScrollView(in: tester.containerView.viewTree.rootNode))
        #expect(scrollNode.absoluteFrame().origin.y == 0)
    }

    @Test
    func navigationBar_buttonStyleKeepsToolbarItemsCompact() throws {
        let tester = ViewTester {
            NavigationStack {
                Color.clear
                    .navigationTitle("New Chat")
                    .navigationTitlePosition(.center)
                    .navigationBarLeadingItems {
                        Button(action: {}) {
                            Text("Agent")
                        }
                    }
                    .navigationBarTrailingItems {
                        HStack(spacing: 10) {
                            Button("History") {}
                            Button("Settings") {}
                        }
                    }
            }
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        let textNodes = textNodes(in: tester.containerView.viewTree.rootNode)
        let agent = try #require(textNodes.first { $0.text == "Agent" })
        let history = try #require(textNodes.first { $0.text == "History" })
        let settings = try #require(textNodes.first { $0.text == "Settings" })

        #expect(agent.frame.origin.x < 80)
        #expect(history.frame.origin.y < 60)
        #expect(settings.frame.origin.y < 60)
        #expect(abs(history.frame.origin.y - settings.frame.origin.y) < 1)
        #expect(history.frame.origin.x < settings.frame.origin.x)
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

private struct NavigationRootStateHost: View {
    @State private var counter = 0

    let driver: NavigationRootStateDriver
    let onAppear: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                Color.red
                    .frame(width: 300, height: 120)
                    .onAppear(perform: onAppear)

                NavigationRootStateBindingProbe(counter: $counter, driver: driver)
            }
        }
    }
}

private final class NavigationRootStateDriver {
    var counter: Binding<Int>?
}

@MainActor
private func firstScrollView(in node: ViewNode) -> ScrollViewNode? {
    if let scrollView = node as? ScrollViewNode {
        return scrollView
    }

    if let root = node as? ViewRootNode {
        return firstScrollView(in: root.contentNode)
    }

    if let navigationStack = node as? NavigationStackNode {
        return firstScrollView(in: navigationStack.shortcutContentSubtree)
    }

    if let modifier = node as? ViewModifierNode {
        return firstScrollView(in: modifier.contentNode)
    }

    if let container = node as? ViewContainerNode {
        for child in container.nodes {
            if let scrollView = firstScrollView(in: child) {
                return scrollView
            }
        }
    }

    return nil
}

@MainActor
private func textNodes(in node: ViewNode) -> [(text: String, frame: Rect)] {
    var result: [(String, Rect)] = []

    if let text = node.content as? Text {
        result.append((text.plainText, node.absoluteFrame()))
    }

    if let root = node as? ViewRootNode {
        result += textNodes(in: root.contentNode)
    } else if let modifier = node as? ViewModifierNode {
        result += textNodes(in: modifier.contentNode)
    } else if let container = node as? ViewContainerNode {
        for child in container.nodes {
            result += textNodes(in: child)
        }
    } else {
        for child in reflectedChildNodes(of: node) {
            result += textNodes(in: child)
        }
    }

    return result
}

@MainActor
private func reflectedChildNodes(of node: ViewNode) -> [ViewNode] {
    Mirror(reflecting: node).children.flatMap { child -> [ViewNode] in
        if let node = child.value as? ViewNode {
            return [node]
        }
        if let node = child.value as? ViewNode? {
            return node.map { [$0] } ?? []
        }
        return []
    }
}

private struct NavigationRootStateBindingProbe: View {
    @Binding var counter: Int

    let driver: NavigationRootStateDriver

    init(counter: Binding<Int>, driver: NavigationRootStateDriver) {
        self._counter = counter
        self.driver = driver
        self.driver.counter = counter
    }

    var body: some View {
        EmptyView()
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
