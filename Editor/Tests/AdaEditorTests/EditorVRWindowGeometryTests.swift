import Math
import Testing

@testable import AdaEditor

struct EditorVRWindowGeometryTests {
    @Test("Manual window sizes survive repeated dock transitions", arguments: [Size(width: 1320, height: 740), Size(width: 2500, height: 1200)])
    func restoresManualSize(_ size: Size) {
        var geometry = EditorVRWindowGeometry()
        geometry.transition(to: .studio)
        geometry.observe(geometry.requestedSize)
        geometry.observe(size)
        for _ in 0..<3 {
            geometry.transition(to: .dock)
            geometry.observe(Size(width: 824, height: 132))
            #expect(geometry.studioSize == size)
            geometry.transition(to: .studio)
            #expect(geometry.requestedSize == size)
            geometry.observe(Size(width: 1000, height: 600))
            #expect(geometry.studioSize == size)
            geometry.observe(size)
        }
    }

    @Test("Wide persists after immersion and subsequent corner resizing is recorded")
    func wideAndResize() {
        var geometry = EditorVRWindowGeometry()
        geometry.transition(to: .studio)
        geometry.observe(geometry.requestedSize)
        geometry.wide()
        #expect(geometry.requestedSize == Size(width: 2200, height: 900))
        geometry.observe(geometry.requestedSize)
        geometry.transition(to: .dock)
        geometry.transition(to: .studio)
        #expect(geometry.requestedSize == Size(width: 2200, height: 900))
        geometry.observe(geometry.requestedSize)
        geometry.observe(Size(width: 2300, height: 950))
        geometry.transition(to: .dock)
        geometry.transition(to: .studio)
        #expect(geometry.requestedSize == Size(width: 2300, height: 950))
    }

    @Test("Chooser geometry and rejected requests cannot overwrite Studio geometry")
    func independentWindows() {
        var geometry = EditorVRWindowGeometry()
        geometry.observe(Size(width: 1120, height: 720))
        geometry.transition(to: .studio)
        geometry.observe(geometry.requestedSize)
        geometry.observe(Size(width: 1800, height: 1000))
        geometry.transition(to: .chooser)
        #expect(geometry.requestedSize == Size(width: 1120, height: 720))
        geometry.observe(geometry.requestedSize)
        geometry.transition(to: .studio)
        #expect(geometry.requestedSize == Size(width: 1800, height: 1000))
        geometry.rejectRequest()
        geometry.observe(Size(width: 1700, height: 850))
        geometry.observe(Size(width: .nan, height: 900))
        geometry.observe(Size(width: 824, height: 132))
        #expect(geometry.studioSize == Size(width: 1700, height: 850))
    }
}
