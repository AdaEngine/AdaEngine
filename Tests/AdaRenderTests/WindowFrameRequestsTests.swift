import AdaECS
@_spi(Internal) @testable import AdaRender
import AdaUtils
import Testing

@Suite("Window frame demand")
struct WindowFrameRequestsTests {
    private let first = WindowID()
    private let second = WindowID()

    @Test("Extract initializes optional demand from both UI and standalone render worlds")
    func extractsOptionalRequests() {
        let world = World()
        let absent = Extract<Res<WindowFrameRequests?>>(from: world)
        #expect(absent.wrappedValue.wrappedValue == nil)
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        world.insertResource(requests)
        let present = Extract<Res<WindowFrameRequests?>>(from: world)
        #expect(present.wrappedValue.wrappedValue?.shouldRender(first) == false)
    }

    @Test("A skipped drawable retries until acquisition succeeds, including resize skips")
    func skippedDrawableRetainsRequest() {
        var requests = WindowFrameRequests()
        var pending = PendingWindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        requests.requestedWindowIDs.insert(first)
        pending.include(requests)
        for _ in 0..<3 {
            let shouldAcquire = pending.shouldAcquireDrawable(for: first, requests: requests)
            #expect(shouldAcquire)
            requests.beginFrame()
            requests.include(.primary, primary: first, onDemand: true)
        }
        pending.didAcquireDrawable(for: first)
        let shouldAcquire = pending.shouldAcquireDrawable(for: first, requests: requests)
        #expect(!shouldAcquire)
    }

    @Test("Closing a window removes its retry without discarding another pending update")
    func closedWindowsDropPendingRequests() {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        requests.include(.windowId(second), primary: first, onDemand: true)
        requests.requestedWindowIDs = [first, second]
        var pending = PendingWindowFrameRequests()
        pending.include(requests)
        requests.requestedWindowIDs.removeAll()
        pending.retainWindows([second])
        let closed = pending.shouldAcquireDrawable(for: first, requests: requests)
        let open = pending.shouldAcquireDrawable(for: second, requests: requests)
        #expect(!closed)
        #expect(open)
    }

    @Test("An unchanged UI camera skips presentation and uses idle frame pacing")
    func unchangedWindow() {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        #expect(!requests.shouldRender(first))
        #expect(!requests.expectsPresentation)
        // A window outside the opt-in policy retains ordinary rendering.
        #expect(requests.shouldRender(second))
    }

    @Test("A new viewport frame requests presentation without affecting another window")
    func updatedTexture() {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        requests.include(.windowId(second), primary: first, onDemand: true)
        requests.requestedWindowIDs.insert(second)
        #expect(!requests.shouldRender(first))
        #expect(requests.shouldRender(second))
        #expect(requests.expectsPresentation)
    }

    @Test("A regular scene camera keeps a shared UI window rendering", arguments: [true, false])
    func sceneCameraOverridesDemand(uiCameraFirst: Bool) {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: uiCameraFirst)
        requests.include(.windowId(first), primary: first, onDemand: !uiCameraFirst)
        #expect(requests.shouldRender(first))
        #expect(requests.expectsPresentation)
    }

    @Test("Frame reset removes old requests and camera policies")
    func reset() {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: first, onDemand: true)
        requests.requestedWindowIDs.insert(first)
        requests.beginFrame()
        requests.include(.windowId(second), primary: first, onDemand: true)
        #expect(!requests.shouldRender(second))
        #expect(!requests.expectsPresentation)
        #expect(requests.shouldRender(first))
    }

    @Test("An unresolved primary window and legacy cameras retain ordinary pacing")
    func unresolvedPrimary() {
        var requests = WindowFrameRequests()
        requests.include(.primary, primary: nil, onDemand: true)
        #expect(requests.shouldRender(first))
        #expect(requests.expectsPresentation)
    }
}
