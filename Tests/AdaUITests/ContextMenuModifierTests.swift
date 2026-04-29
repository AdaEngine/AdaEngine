import AdaInput
import AdaUtils
import Math
import Testing

@_spi(Internal) @testable import AdaUI
@testable import AdaPlatform

@MainActor
@Suite(.serialized)
struct ContextMenuModifierTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func contextMenuPresentsOnRightClick() {
        var captured: ContextMenuPresentation?
        var didDelete = false

        ContextMenuPresentationCenter.present = { presentation in
            captured = presentation
        }

        let tester = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        didDelete = true
                    }
                    Button("Rename") {}
                }
        }
        .setSize(Size(width: 100, height: 100))
        .performLayout()

        tester.sendMouseEvent(at: Point(50, 50), button: .right, phase: .began)

        #expect(captured?.location == Point(50, 50))
        #expect(captured?.items.map(\.title) == ["Delete", "Rename"])
        #expect(captured?.items.first?.role == .destructive)

        captured?.items.first?.action?()
        #expect(didDelete)

        ContextMenuPresentationCenter.present = nil
    }

    @Test
    func contextMenuPresentsAfterLongPress() {
        var captured: ContextMenuPresentation?

        ContextMenuPresentationCenter.present = { presentation in
            captured = presentation
        }

        let tester = ViewTester {
            Color.red
                .frame(width: 100, height: 100)
                .contextMenu {
                    Button("Open") {}
                }
        }
        .setSize(Size(width: 100, height: 100))
        .performLayout()

        tester.sendMouseEvent(at: Point(40, 40), phase: .began)
        tester.containerView.viewTree.rootNode.update(0.4)
        #expect(captured == nil)

        tester.containerView.viewTree.rootNode.update(0.2)
        #expect(captured?.location == Point(40, 40))
        #expect(captured?.items.map(\.title) == ["Open"])

        ContextMenuPresentationCenter.present = nil
    }

    @Test
    func longPressContextMenuCancelsPrimaryButtonAction() {
        var captured: ContextMenuPresentation?
        var didTapPrimaryAction = false

        ContextMenuPresentationCenter.present = { presentation in
            captured = presentation
        }

        let tester = ViewTester {
            Button("Primary") {
                didTapPrimaryAction = true
            }
            .frame(width: 100, height: 100)
            .contextMenu {
                Button("Open") {}
            }
        }
        .setSize(Size(width: 100, height: 100))
        .performLayout()

        tester.sendMouseEvent(at: Point(50, 50), phase: .began)
        tester.containerView.viewTree.rootNode.update(0.6)
        tester.sendMouseEvent(at: Point(50, 50), phase: .ended)

        #expect(captured?.items.map(\.title) == ["Open"])
        #expect(!didTapPrimaryAction)

        ContextMenuPresentationCenter.present = nil
    }
}
