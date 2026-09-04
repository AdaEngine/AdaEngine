@testable import AdaRender
import AdaScripting
@testable import AdaUI
import Math
import Testing

@MainActor
@Suite("Ada Script views", .serialized)
struct AdaScriptViewTests {
    init() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }

    @Test("Builds a native AdaUI hierarchy from @view")
    func buildsNativeViewHierarchy() throws {
        let view = try AdaScriptView(
            sources: [
                AdaScriptSource(
                    path: "Views/Welcome.ada",
                    source: """
                    @view
                    class WelcomeView {
                        func body() {
                            VStack(spacing: 12) {
                                Text("Hello from Ada Script").fontSize(28);
                                HStack {
                                    Text("Native AdaUI");
                                    Spacer();
                                    Divider();
                                }
                            }
                            .padding(24)
                            .background("#20232aff")
                            .accessibilityIdentifier("welcome-root");
                        }
                    }
                    """
                )
            ],
            identifier: "WelcomeView"
        )
        let container = UIContainerView(rootView: view)
        container.frame.size = Size(width: 480, height: 320)
        container.layoutSubviews()

        let root = try #require(container.uiTreeRoots().first)
        #expect(flatten(root).contains { $0.accessibilityIdentifier == "welcome-root" })
        #expect(flatten(root).filter { $0.viewType.contains("AdaUI.Text") }.count == 2)
    }

    @Test("Requires body() to return a view value")
    func rejectsInvalidBody() {
        #expect(throws: AdaScriptError.self) {
            try AdaScriptView(
                sources: [
                    AdaScriptSource(
                        path: "Invalid.ada",
                        source: "@view class InvalidView { func body() { return 42; } }"
                    )
                ],
                identifier: "InvalidView"
            )
        }
    }

    @Test("State survives actions and invalidates the native view")
    func stateSurvivesButtonAction() throws {
        let view = try AdaScriptView(
            sources: [
                AdaScriptSource(
                    path: "Counter.ada",
                    source: """
                    @view
                    class CounterView {
                        @state var label = "Before";

                        func body() {
                            VStack {
                                Text(label);
                                Button("Change") {
                                    label = "After";
                                }.accessibilityIdentifier("change-label");
                            };
                        }
                    }
                    """
                )
            ],
            identifier: "CounterView"
        )
        let container = UIContainerView(rootView: view)
        container.frame.size = Size(width: 320, height: 200)
        container.layoutSubviews()

        #expect(textValues(in: container.viewTree.rootNode).contains("Before"))
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("change-label"))
        container.layoutSubviews()
        #expect(textValues(in: container.viewTree.rootNode).contains("After"))
    }

    @Test("Environment values are rebound before body evaluation")
    func environmentValuesAreBound() throws {
        let view = try AdaScriptView(
            sources: [
                AdaScriptSource(
                    path: "Themed.ada",
                    source: """
                    @view
                    class ThemedView {
                        @environment(colorScheme) var scheme;
                        func body() { Text(scheme); }
                    }
                    """
                )
            ],
            identifier: "ThemedView"
        )
        let container = UIContainerView(rootView: view.preferredColorScheme(.dark))
        container.frame.size = Size(width: 320, height: 200)
        container.layoutSubviews()

        #expect(textValues(in: container.viewTree.rootNode).contains("dark"))
    }

    private func flatten(_ root: UINodeSnapshot) -> [UINodeSnapshot] {
        [root] + root.children.flatMap(flatten)
    }

    private func textValues(in node: ViewNode) -> [String] {
        var values: [String] = []
        if let text = node.content as? Text {
            values.append(text.plainText)
        }
        values += node.transientEnvironmentChildren.flatMap(textValues)
        return values
    }
}
