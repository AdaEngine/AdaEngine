import AdaAnimation
import AdaECS
import AdaScene
import Testing

// Minimal KeyframeAnimatable used only in tests; applies nothing (no world access needed).
private struct TestAnim: KeyframeAnimatable {
    var x: Float = 0
    func apply(to entityId: Entity.ID, in world: World) {}
}

struct KeyframeAnimatorTests {

    @Test
    func playClipSetsRequestedClipAndIncrementsToken() {
        let a = KeyframeClip(name: "a", initialValues: TestAnim(), duration: 1, repeatMode: .once)
        let b = KeyframeClip(name: "b", initialValues: TestAnim(), duration: 1, repeatMode: .once)
        var animator = KeyframeAnimator(clips: [AnyAnimatorClip(a), AnyAnimatorClip(b)], initialClipName: "a")
        let tokenBefore = animator.runToken

        animator.playClip(by: "b")

        #expect(animator.requestedClipName == "b")
        #expect(animator.playbackState == .playing)
        #expect(animator.runToken == tokenBefore + 1)
    }

    @Test
    func stopTransitionsToStoppedAndIncrementsToken() {
        let clip = KeyframeClip(name: "idle", initialValues: TestAnim(), duration: 1, repeatMode: .once)
        var animator = KeyframeAnimator(clips: [AnyAnimatorClip(clip)], initialClipName: "idle")
        let tokenBefore = animator.runToken

        animator.stop()

        #expect(animator.playbackState == .stopped)
        #expect(animator.runToken == tokenBefore + 1)
    }

    @Test
    func builderInitSelectsFirstClipAsDefault() {
        var animator = KeyframeAnimator {
            KeyframeClip(name: "intro", initialValues: TestAnim(), duration: 0.5, repeatMode: .once)
            KeyframeClip(name: "loop", initialValues: TestAnim(), duration: 1, repeatMode: .loop())
        }
        #expect(animator.currentClipName == "intro")
        animator.playClip(by: "loop")
        #expect(animator.requestedClipName == "loop")
    }
}
