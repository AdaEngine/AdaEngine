import AdaInput
@testable import AdaPlatform
import AdaUtils
import Math
import Testing

@_spi(Internal) @testable import AdaUI

@Suite("Embedded native hover regions", .serialized)
@MainActor
struct UIHoverRegionTests {
    init() async throws { try Application.prepareForTest() }
    @Test("Enabled button and primary picker have regions; disabled controls and labels do not")
    func semanticControls() throws {
        var selected = "visible"
        let container = UIContainerView(rootView: VStack {
            Button("Enabled") {}
            Button("Disabled") {}.disabled(true)
            Text("Label")
            Text("Clickable row").onTapGesture {}
            Text("Picker").frame(width: 100, height: 32).contextMenu(opensOnPrimaryAction: true) {
                ContextMenuOption("visible", isSelected: selected == "visible") { selected = "visible" }
                ContextMenuOption("hidden", isSelected: selected == "hidden") { selected = "hidden" }
            }
        })
        container.frame = Rect(x: 0, y: 0, width: 200, height: 200)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let regions = container.uiHoverRegions()
        #expect(regions.count == 3)
        #expect(regions.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 })
    }

    @Test("Focused text inputs lose gaze highlighting and regain it after focus moves")
    func textInputFocus() throws {
        let container = UIContainerView(rootView: VStack {
            TextEditor(text: .constant("code"))
                .frame(width: 180, height: 80)
            TextField("Name", text: .constant("Ada"))
                .frame(width: 180, height: 32)
            Button("Action") {}
                .frame(width: 180, height: 32)
        })
        container.frame = Rect(x: 0, y: 0, width: 200, height: 200)
        container.bounds.size = container.frame.size
        let initialRegions = container.uiHoverRegions()
        #expect(initialRegions.count == 3)

        for region in initialRegions.prefix(2) {
            let point = Point(region.frame.midX, region.frame.midY)
            let contact = RID()
            container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 1, contactID: contact)])
            container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .ended, time: 1.1, contactID: contact)])
            let focusedNode = try #require(container.focusManager.focusedNode)
            let focusedID = UInt(bitPattern: focusedNode.id)
            #expect(initialRegions.contains { $0.id == focusedID })
            #expect(container.uiHoverRegions() == initialRegions.filter { $0.id != focusedID })
        }

        container.focusManager.focusNext()
        #expect(container.focusManager.focusedNode is ButtonViewNode)
        #expect(container.uiHoverRegions() == initialRegions)
        container.focusManager.focus(nil)
        #expect(container.uiHoverRegions() == initialRegions)
    }

    @Test("Hover registration leaves nested button touch routing intact")
    func touchStillClicks() throws {
        var clicked = 0
        let container = UIContainerView(rootView: Button("Action") { clicked += 1 }.frame(width: 120, height: 44))
        container.frame = Rect(x: 0, y: 0, width: 120, height: 44)
        container.bounds.size = container.frame.size
        let region = try #require(container.uiHoverRegions().first)
        let point = Point(region.frame.midX, region.frame.midY)
        let id = RID()
        container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 1, contactID: id)])
        container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .ended, time: 1.1, contactID: id)])
        #expect(clicked == 1)
    }

    @Test("Touch passes through a hover wrapper and decorative overlay to the nested button")
    func hoverWrappedTouch() {
        var clicks = 0
        let container = UIContainerView(rootView: Button("Action") { clicks += 1 }
            .frame(width: 44, height: 44)
            .overlay { Color.clear.allowsHitTesting(false) }
            .onHover { _ in })
        container.frame = Rect(x: 0, y: 0, width: 44, height: 44)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let point = Point(22, 22)
        let id = RID()
        container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 1, contactID: id)])
        container.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .ended, time: 1.1, contactID: id)])
        #expect(clicks == 1)
    }

    @Test("Scrollable content exposes only clipped, visible hover bounds")
    func scrollClipping() {
        let container = UIContainerView(rootView: ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { index in
                    Button("Row \(index)") {}.frame(width: 150, height: 50)
                }
            }
        }.frame(width: 150, height: 100))
        container.frame = Rect(x: 0, y: 0, width: 150, height: 100)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let regions = container.uiHoverRegions()
        #expect(!regions.isEmpty && regions.count < 10)
        #expect(regions.allSatisfy { $0.frame.minY >= 0 && $0.frame.maxY <= 100 })
    }
}
