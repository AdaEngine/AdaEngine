import AdaInput
import AdaPlatform
import AdaUIDescription
import AdaUtils
import Math
import Testing

@testable import AdaUI

@Suite(.serialized) @MainActor
struct FreeLayoutTests {
    init() async throws { try Application.prepareForTest() }

    @Test func relativePositionResizesWithoutChangingChildSize() throws {
        let tester = ViewTester {
            FreeLayout {
                Color.red.frame(width: 100, height: 40).relativePosition(x: 0.75, y: 1)
                    .background(Color.blue).overlay { Color.clear }.accessibilityIdentifier("placed")
                Color.blue.frame(width: 40, height: 20).accessibilityIdentifier("centered")
            }
        }.setSize(Size(width: 500, height: 300)).performLayout()
        let placed = try #require(tester.findNodeByAccessibilityIdentifier("placed"))
        #expect(placed.frame == Rect(x: 300, y: 260, width: 100, height: 40))
        let centered = try #require(tester.findNodeByAccessibilityIdentifier("centered"))
        #expect(centered.frame.origin == Point(230, 140))
        tester.setSize(Size(width: 300, height: 200)).performLayout()
        #expect(placed.frame == Rect(x: 150, y: 160, width: 100, height: 40))
    }

    @Test func yamlCatalogAndRuntimeUseTheSamePlacement() throws {
        let child = UINodeDescription(type: "Text", arguments: ["text": .init(value: .string("HUD"))], modifiers: [
            .init(type: "frame", arguments: ["width": .init(value: .number(100)), "height": .init(value: .number(40))]),
            .init(type: "relativePosition", arguments: ["x": .init(value: .number(1)), "y": .init(value: .number(0))])
        ])
        let document = UISceneDocument(root: .init(type: "FreeLayout", children: [child]))
        let decoded = try UISceneDocument.decode(document.encodedYAML())
        #expect(decoded == document)
        let session = try UISceneInstance(document: decoded)
        let view = UIContainerView(rootView: UISceneView(session: session))
        view.frame = Rect(x: 0, y: 0, width: 400, height: 250)
        view.layoutIfNeeded()
        func find(_ snapshot: UINodeSnapshot) -> Rect? {
            snapshot.sceneNodeID == child.id ? snapshot.absoluteFrame : snapshot.children.compactMap(find).first
        }
        #expect(view.uiTreeRoots().compactMap(find).first == Rect(x: 300, y: 0, width: 100, height: 40))
    }

    @Test func placementClampsAndDoesNotLeakIntoOtherLayouts() throws {
        let tester = ViewTester {
            HStack(spacing: 0) {
                Color.red.frame(width: 40, height: 20).relativePosition(x: 1, y: 1).accessibilityIdentifier("first")
                Color.blue.frame(width: 40, height: 20).accessibilityIdentifier("second")
            }
        }.setSize(Size(width: 80, height: 20)).performLayout()
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("first")).frame.origin == Point.zero)
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("second")).frame.origin == Point(40, 0))
        let free = ViewTester {
            FreeLayout { Color.red.frame(width: 200, height: 200).relativePosition(x: .infinity, y: -1).accessibilityIdentifier("large") }
        }.setSize(Size(width: 100, height: 100)).performLayout()
        #expect(try #require(free.findNodeByAccessibilityIdentifier("large")).frame.origin == .zero)
    }

    @Test func heldTouchDragCancelsButtonTapAndExplicitCancellation() {
        var taps = 0, changes = 0, drops = 0, cancellations = 0
        let tester = ViewTester {
            Button("Drag") { taps += 1 }.frame(width: 100, height: 40)
                .gesture(DragGesture(minimumDistance: 8, minimumPressDuration: 0.3)
                    .onChanged { _ in changes += 1 }.onEnded { _ in drops += 1 }.onCancelled { cancellations += 1 })
        }.setSize(Size(width: 100, height: 40)).performLayout()
        let window = tester.containerView.window?.id ?? .empty
        func touch(_ phase: TouchEvent.Phase, _ time: Float) {
            tester.containerView.onTouchesEvent([TouchEvent(window: window, location: Point(50, 20), phase: phase, time: time)])
        }
        touch(.began, 0)
        tester.containerView.update(0.31)
        touch(.ended, 0.4)
        #expect(changes == 1 && drops == 1 && taps == 0)
        touch(.began, 1)
        tester.containerView.update(0.31)
        touch(.cancelled, 1.4)
        #expect(cancellations == 1 && drops == 1)
    }

    @Test func quickSwipeScrollsInsteadOfStartingHeldDrag() throws {
        var changes = 0
        let tester = ViewTester {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { index in
                        Button("Row \(index)") {}.frame(width: 100, height: 40)
                            .gesture(DragGesture(minimumDistance: 8, minimumPressDuration: 0.3).onChanged { _ in changes += 1 })
                            .accessibilityIdentifier("row\(index)")
                    }
                }
            }
        }.setSize(Size(width: 100, height: 200)).performLayout()
        let before = try tester.containerView.uiNode(matching: .accessibilityIdentifier("row3")).absoluteFrame.minY
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(50, 20), phase: .began, time: 0)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(50, -60), phase: .moved, time: 0.1)])
        tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: Point(50, -60), phase: .ended, time: 0.2)])
        tester.performLayout()
        let after = try tester.containerView.uiNode(matching: .accessibilityIdentifier("row3")).absoluteFrame.minY
        #expect(changes == 0 && after < before)
    }
}
