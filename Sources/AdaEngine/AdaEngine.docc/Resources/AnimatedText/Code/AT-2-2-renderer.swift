import AdaEngine

struct AnimatedSineWaveRenderer: TextRenderer {
    var timeOffset: Double

    var animatableData: Double {
        get { timeOffset }
        set { timeOffset = newValue }
    }

    init(timeOffset: Double) {
        self.timeOffset = timeOffset
    }
}
