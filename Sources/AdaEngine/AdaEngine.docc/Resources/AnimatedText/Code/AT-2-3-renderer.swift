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

    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        let glyphs = layout.flattenedRuns
        let safeCount = max(glyphs.count, 1)
        let width = layout.first?.typographicBounds.rect.width ?? 1
        let height = layout.first?.typographicBounds.rect.height ?? 1

        for (index, glyph) in glyphs.enumerated() {
            let offset = sineOffset(
                index: index,
                amplitude: Double(height) * 0.5,
                wavelength: Double(width),
                phase: timeOffset,
                total: safeCount
            )

            var copy = context
            copy.translateBy(x: 0, y: Float(offset))
            copy.draw(glyph)
        }
    }

    private func sineOffset(
        index: Int,
        amplitude: Double,
        wavelength: Double,
        phase: Double,
        total: Int
    ) -> Double {
        let x = Double(index)
        let position = (x / Double(total)) * wavelength
        let radians = ((position + phase) / wavelength) * 2 * .pi
        return Math.sin(radians) * amplitude
    }
}
