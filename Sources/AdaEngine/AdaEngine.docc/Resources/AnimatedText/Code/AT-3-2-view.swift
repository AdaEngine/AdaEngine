import AdaEngine

struct ContentView: View {
    @State private var timeOffset: Double = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text("Sine Wave")
            .textRendered(AnimatedSineWaveRenderer(timeOffset: timeOffset))
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                timeOffset += 0.12
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}
