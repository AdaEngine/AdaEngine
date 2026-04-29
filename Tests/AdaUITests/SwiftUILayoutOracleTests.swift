#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import AdaPlatform
@testable import AdaUI
import Math

@MainActor
struct SwiftUILayoutOracleTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func hStackFixedChildrenMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 240, height: 120),
            ids: ["root", "a", "b", "c"],
            swiftUI: {
                SwiftUI.HStack(alignment: .center, spacing: 8) {
                    fixedSwiftUIView("a", width: 40, height: 20)
                    fixedSwiftUIView("b", width: 30, height: 50)
                    fixedSwiftUIView("c", width: 20, height: 10)
                }
            },
            adaUI: {
                AdaUI.HStack(alignment: .center, spacing: 8) {
                    fixedAdaUIView("a", width: 40, height: 20)
                    fixedAdaUIView("b", width: 30, height: 50)
                    fixedAdaUIView("c", width: 20, height: 10)
                }
            }
        )
    }

    @Test
    func vStackFixedChildrenMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 180, height: 180),
            ids: ["root", "a", "b", "c"],
            swiftUI: {
                SwiftUI.VStack(alignment: .trailing, spacing: 12) {
                    fixedSwiftUIView("a", width: 40, height: 20)
                    fixedSwiftUIView("b", width: 80, height: 30)
                    fixedSwiftUIView("c", width: 20, height: 40)
                }
            },
            adaUI: {
                AdaUI.VStack(alignment: .trailing, spacing: 12) {
                    fixedAdaUIView("a", width: 40, height: 20)
                    fixedAdaUIView("b", width: 80, height: 30)
                    fixedAdaUIView("c", width: 20, height: 40)
                }
            }
        )
    }

    @Test
    func zStackAnchorsMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 160, height: 140),
            ids: ["root", "a", "b"],
            swiftUI: {
                SwiftUI.ZStack(alignment: .bottomTrailing) {
                    fixedSwiftUIView("a", width: 50, height: 30)
                    fixedSwiftUIView("b", width: 20, height: 60)
                }
            },
            adaUI: {
                AdaUI.ZStack(anchor: .bottomTrailing) {
                    fixedAdaUIView("a", width: 50, height: 30)
                    fixedAdaUIView("b", width: 20, height: 60)
                }
            }
        )
    }

    @Test
    func hStackSpacerSharesRemainingWidthLikeSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 300, height: 80),
            ids: ["root", "leading", "trailing"],
            swiftUI: {
                SwiftUI.HStack(alignment: .center, spacing: 0) {
                    fixedSwiftUIView("leading", width: 40, height: 20)
                    SwiftUI.Spacer()
                    fixedSwiftUIView("trailing", width: 30, height: 20)
                }
            },
            adaUI: {
                AdaUI.HStack(alignment: .center, spacing: 0) {
                    fixedAdaUIView("leading", width: 40, height: 20)
                    AdaUI.Spacer()
                    fixedAdaUIView("trailing", width: 30, height: 20)
                }
            }
        )
    }

    @Test
    func hStackFixedSidebarAndFlexibleContentMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 1600, height: 900),
            ids: ["root", "sidebar", "chat", "composer"],
            swiftUI: {
                SwiftUI.HStack(alignment: .center, spacing: 24) {
                    SwiftUI.Color.clear
                        .frame(width: 292, height: 760)
                        .oracleFrame("sidebar")

                    SwiftUI.ZStack {
                        SwiftUI.Color.clear
                            .frame(width: 380, height: 140)
                            .oracleFrame("composer")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .oracleFrame("chat")
                }
            },
            adaUI: {
                AdaUI.HStack(alignment: .center, spacing: 24) {
                    AdaUI.EmptyView()
                        .frame(width: 292, height: 760)
                        .accessibilityIdentifier("sidebar")

                    AdaUI.ZStack(anchor: .center) {
                        fixedAdaUIView("composer", width: 380, height: 140)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityIdentifier("chat")
                }
            }
        )
    }

    @Test
    func hStackSpacersAroundFlexibleContentMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 1600, height: 900),
            ids: ["root", "sidebar", "chat", "composer"],
            swiftUI: {
                SwiftUI.HStack(alignment: .center, spacing: 24) {
                    SwiftUI.Color.clear
                        .frame(width: 292, height: 760)
                        .oracleFrame("sidebar")

                    SwiftUI.Spacer()

                    SwiftUI.ZStack {
                        SwiftUI.Color.clear
                            .frame(width: 380, height: 140)
                            .oracleFrame("composer")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .oracleFrame("chat")

                    SwiftUI.Spacer()
                }
            },
            adaUI: {
                AdaUI.HStack(alignment: .center, spacing: 24) {
                    AdaUI.EmptyView()
                        .frame(width: 292, height: 760)
                        .accessibilityIdentifier("sidebar")

                    AdaUI.Spacer()

                    AdaUI.ZStack(anchor: .center) {
                        fixedAdaUIView("composer", width: 380, height: 140)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityIdentifier("chat")

                    AdaUI.Spacer()
                }
            }
        )
    }

    @Test
    func vStackMultipleSpacersMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 120, height: 260),
            ids: ["root", "top", "middle", "bottom"],
            swiftUI: {
                SwiftUI.VStack(alignment: .center, spacing: 0) {
                    fixedSwiftUIView("top", width: 30, height: 20)
                    SwiftUI.Spacer()
                    fixedSwiftUIView("middle", width: 70, height: 30)
                    SwiftUI.Spacer(minLength: 10)
                    fixedSwiftUIView("bottom", width: 50, height: 20)
                }
            },
            adaUI: {
                AdaUI.VStack(alignment: .center, spacing: 0) {
                    fixedAdaUIView("top", width: 30, height: 20)
                    AdaUI.Spacer()
                    fixedAdaUIView("middle", width: 70, height: 30)
                    AdaUI.Spacer(minLength: 10)
                    fixedAdaUIView("bottom", width: 50, height: 20)
                }
            }
        )
    }

    @Test
    func flexibleFrameAlignmentMatchesSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 220, height: 160),
            ids: ["root", "frame", "child"],
            swiftUI: {
                fixedSwiftUIView("child", width: 40, height: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .oracleFrame("frame")
            },
            adaUI: {
                fixedAdaUIView("child", width: 40, height: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .accessibilityIdentifier("frame")
            }
        )
    }

    @Test
    func paddingOrderMatchesSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 220, height: 160),
            ids: ["root", "outer", "inner"],
            swiftUI: {
                fixedSwiftUIView("inner", width: 40, height: 20)
                    .padding(SwiftUI.EdgeInsets(top: 5, leading: 10, bottom: 15, trailing: 20))
                    .frame(width: 120, height: 80, alignment: .topLeading)
                    .oracleFrame("outer")
            },
            adaUI: {
                fixedAdaUIView("inner", width: 40, height: 20)
                    .padding(AdaUI.EdgeInsets(top: 5, leading: 10, bottom: 15, trailing: 20))
                    .frame(width: 120, height: 80, alignment: .topLeading)
                    .accessibilityIdentifier("outer")
            }
        )
    }

    @Test
    func fixedSizeMatchesSwiftUIInsideSmallerFrame() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 160, height: 120),
            ids: ["root", "outer", "inner"],
            swiftUI: {
                fixedSwiftUIView("inner", width: 80, height: 30)
                    .fixedSize()
                    .frame(width: 40, height: 10, alignment: .topLeading)
                    .oracleFrame("outer")
            },
            adaUI: {
                fixedAdaUIView("inner", width: 80, height: 30)
                    .fixedSize()
                    .frame(width: 40, height: 10, alignment: .topLeading)
                    .accessibilityIdentifier("outer")
            }
        )
    }

    @Test
    func hStackLayoutPriorityMatchesSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 300, height: 80),
            ids: ["root", "primary", "secondary"],
            swiftUI: {
                SwiftUI.HStack(alignment: .center, spacing: 0) {
                    SwiftUI.Color.clear
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                        .oracleFrame("primary")
                    SwiftUI.Color.clear
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                        .oracleFrame("secondary")
                }
            },
            adaUI: {
                AdaUI.HStack(alignment: .center, spacing: 0) {
                    AdaUI.EmptyView()
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                        .accessibilityIdentifier("primary")
                    AdaUI.EmptyView()
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("secondary")
                }
            }
        )
    }

    @Test
    func geometryReaderMatchesSwiftUITopLeadingPlacement() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 180, height: 120),
            ids: ["root", "geometry", "child"],
            swiftUI: {
                SwiftUI.GeometryReader { _ in
                    fixedSwiftUIView("child", width: 50, height: 30)
                }
                .oracleFrame("geometry")
            },
            adaUI: {
                AdaUI.GeometryReader { _ in
                    fixedAdaUIView("child", width: 50, height: 30)
                }
                .accessibilityIdentifier("geometry")
            }
        )
    }

    @Test
    func scrollViewViewportAndContentMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 220, height: 160),
            ids: ["root", "scroll", "content", "item-0", "item-1"],
            swiftUI: {
                SwiftUI.ScrollView(.vertical) {
                    SwiftUI.VStack(alignment: .leading, spacing: 8) {
                        fixedSwiftUIView("item-0", width: 70, height: 40)
                        fixedSwiftUIView("item-1", width: 90, height: 50)
                    }
                    .oracleFrame("content")
                }
                .scrollIndicators(.hidden)
                .frame(width: 120, height: 80)
                .oracleFrame("scroll")
            },
            adaUI: {
                AdaUI.ScrollView(.vertical) {
                    AdaUI.VStack(alignment: .leading, spacing: 8) {
                        fixedAdaUIView("item-0", width: 70, height: 40)
                        fixedAdaUIView("item-1", width: 90, height: 50)
                    }
                    .accessibilityIdentifier("content")
                }
                .frame(width: 120, height: 80)
                .accessibilityIdentifier("scroll")
            }
        )
    }

    @Test
    func edgeCaseEmptyAndSingleChildStacksMatchSwiftUI() {
        assertLayoutMatchesSwiftUI(
            size: Size(width: 180, height: 120),
            ids: ["root", "empty", "single", "child"],
            swiftUI: {
                SwiftUI.VStack(alignment: .leading, spacing: 8) {
                    SwiftUI.HStack(spacing: 0) {}
                        .oracleFrame("empty")
                    SwiftUI.HStack(spacing: 0) {
                        fixedSwiftUIView("child", width: 45, height: 25)
                    }
                    .oracleFrame("single")
                }
            },
            adaUI: {
                AdaUI.VStack(alignment: .leading, spacing: 8) {
                    AdaUI.HStack(spacing: 0) {}
                        .accessibilityIdentifier("empty")
                    AdaUI.HStack(spacing: 0) {
                        fixedAdaUIView("child", width: 45, height: 25)
                    }
                    .accessibilityIdentifier("single")
                }
            }
        )
    }
}

private let oracleRootID = "root"
private let oracleCoordinateSpace = "SwiftUILayoutOracleRoot"

private struct OracleFramePreferenceKey: SwiftUI.PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct OracleFrameTag: SwiftUI.ViewModifier {
    let id: String

    func body(content: Content) -> some SwiftUI.View {
        content.background(
            SwiftUI.GeometryReader { proxy in
                SwiftUI.Color.clear.preference(
                    key: OracleFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(oracleCoordinateSpace))]
                )
            }
        )
    }
}

private extension SwiftUI.View {
    @MainActor
    func oracleFrame(_ id: String) -> some SwiftUI.View {
        modifier(OracleFrameTag(id: id))
    }
}

@MainActor
private final class SwiftUIFrameStore {
    var frames: [String: CGRect] = [:]
}

@MainActor
private enum SwiftUIOracleHost {
    static func frames<Content: SwiftUI.View>(
        size: Size,
        @SwiftUI.ViewBuilder content: () -> Content
    ) -> [String: Rect] {
        let store = SwiftUIFrameStore()
        let rootView = SwiftUI.ZStack(alignment: .topLeading) {
            content()
        }
        .frame(width: CGFloat(size.width), height: CGFloat(size.height), alignment: .topLeading)
            .coordinateSpace(name: oracleCoordinateSpace)
            .oracleFrame(oracleRootID)
            .onPreferenceChange(OracleFramePreferenceKey.self) { frames in
            store.frames = frames
        }

        let host = NSHostingView(rootView: rootView)
        host.frame = CGRect(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height))

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()

        for _ in 0..<4 {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            window.layoutIfNeeded()
            host.layoutSubtreeIfNeeded()
        }

        window.contentView = nil
        return store.frames.mapValues { Rect($0) }
    }
}

@MainActor
private enum AdaUILayoutProbe {
    static func frames<Content: AdaUI.View>(
        size: Size,
        ids: [String],
        @AdaUI.ViewBuilder content: @escaping () -> Content
    ) -> [String: Rect] {
        let tester = ViewTester {
            content()
                .frame(minWidth: size.width, maxWidth: size.width, minHeight: size.height, maxHeight: size.height, alignment: .topLeading)
                .accessibilityIdentifier(oracleRootID)
        }
        .setSize(size)
        .performLayout()

        var result: [String: Rect] = [:]
        for id in ids {
            guard let node = tester.findNodeByAccessibilityIdentifier(id) else {
                continue
            }
            result[id] = node.absoluteFrame()
        }
        return result
    }
}

@MainActor
private func assertLayoutMatchesSwiftUI<SwiftContent: SwiftUI.View, AdaContent: AdaUI.View>(
    size: Size,
    ids: [String],
    tolerance: Float = 0.5,
    @SwiftUI.ViewBuilder swiftUI: () -> SwiftContent,
    @AdaUI.ViewBuilder adaUI: @escaping () -> AdaContent,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let swiftFrames = SwiftUIOracleHost.frames(size: size, content: swiftUI)
    let adaFrames = AdaUILayoutProbe.frames(size: size, ids: ids, content: adaUI)

    for id in ids {
        guard let expected = swiftFrames[id] else {
            Issue.record("SwiftUI did not report frame for '\(id)'", sourceLocation: sourceLocation)
            continue
        }
        guard let actual = adaFrames[id] else {
            Issue.record("AdaUI did not report frame for '\(id)'", sourceLocation: sourceLocation)
            continue
        }

        assertRect(
            actual,
            matches: expected,
            tolerance: tolerance,
            id: id,
            sourceLocation: sourceLocation
        )
    }
}

private func assertRect(
    _ actual: Rect,
    matches expected: Rect,
    tolerance: Float,
    id: String,
    sourceLocation: SourceLocation
) {
    #expect(abs(actual.origin.x - expected.origin.x) <= tolerance, "Frame \(id) x: AdaUI \(actual.origin.x), SwiftUI \(expected.origin.x)", sourceLocation: sourceLocation)
    #expect(abs(actual.origin.y - expected.origin.y) <= tolerance, "Frame \(id) y: AdaUI \(actual.origin.y), SwiftUI \(expected.origin.y)", sourceLocation: sourceLocation)
    #expect(abs(actual.width - expected.width) <= tolerance, "Frame \(id) width: AdaUI \(actual.width), SwiftUI \(expected.width)", sourceLocation: sourceLocation)
    #expect(abs(actual.height - expected.height) <= tolerance, "Frame \(id) height: AdaUI \(actual.height), SwiftUI \(expected.height)", sourceLocation: sourceLocation)
}

@MainActor
private func fixedSwiftUIView(_ id: String, width: CGFloat, height: CGFloat) -> some SwiftUI.View {
    SwiftUI.Color.clear
        .frame(width: width, height: height)
        .oracleFrame(id)
}

@MainActor
private func fixedAdaUIView(_ id: String, width: Float, height: Float) -> some AdaUI.View {
    AdaUI.EmptyView()
        .frame(width: width, height: height)
        .accessibilityIdentifier(id)
}

private extension Rect {
    init(_ rect: CGRect) {
        self.init(
            x: Float(rect.origin.x),
            y: Float(rect.origin.y),
            width: Float(rect.width),
            height: Float(rect.height)
        )
    }
}
#endif
