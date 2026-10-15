#if os(Windows)
import AdaUtils
import Testing

@Suite("Windows high-resolution time")
struct WindowsTimeTests {
    @Test("Frame clock resolves intervals below one millisecond")
    func submillisecondResolution() {
        var previous = Time.absolute
        var smallestStep = Double.infinity
        var monotonic = true
        for _ in 0..<10_000 {
            let current = Time.absolute
            monotonic = monotonic && current >= previous
            if current > previous { smallestStep = min(smallestStep, current - previous) }
            previous = current
        }
        #expect(monotonic)
        #expect(smallestStep > 0 && smallestStep < 0.001)
    }

    @Test("Elapsed seconds agree with ContinuousClock")
    func elapsedSeconds() async throws {
        let clock = ContinuousClock()
        let started = clock.now
        let engineStarted = Time.absolute
        try await clock.sleep(for: .milliseconds(100))
        let engineElapsed = Time.absolute - engineStarted
        let elapsed = started.duration(to: clock.now).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        #expect(abs(engineElapsed - seconds) < 0.005)
    }

    @Test("Concurrent readers use the same monotonic clock")
    func concurrentReaders() async {
        let started = Time.absolute
        let samples = await withTaskGroup(of: Double.self, returning: [Double].self) { group in
            for _ in 0..<16 { group.addTask { Time.absolute } }
            var values: [Double] = []
            for await value in group { values.append(value) }
            return values
        }
        let ended = Time.absolute
        #expect(samples.count == 16)
        #expect(samples.allSatisfy { $0 >= started && $0 <= ended })
    }
}
#endif
