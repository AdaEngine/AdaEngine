//
//  AnimatedTextRendererApp.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.12.2025.
//

import AdaEngine

@main
struct AnimatedTextRendererApp: App {
    var body: some AppScene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isAnimated: Bool = false
    @State private var timeOffset: Double = 0.0

    var body: some View {
        Text("Some wave")
            .textRendered(AnimatedSineWaveOffsetRender(timeOffset: timeOffset))
            .onAppear {
                isAnimated = true
            }
    }
}

extension Text.Layout {
    var runs: some RandomAccessCollection<TextRun> {
        flatMap { line in
            line
        }
    }

    var flattenedRuns: some RandomAccessCollection<Glyph> {
        runs.flatMap { $0 }
    }
}

struct AnimatedSineWaveOffsetRender: TextRenderer {
    let timeOffset: Double // Time offset

    init(timeOffset: Double) {
        self.timeOffset = timeOffset
    }

    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        let count = layout.flattenedRuns.count // Count all RunSlices in the text layout
        let width = layout.first?.typographicBounds.rect.width ?? 0 // Get the width of the text line
        let height = layout.first?.typographicBounds.rect.height ?? 0 // Get the height of the text line
        // Iterate through each RunSlice and its index
        for (index, glyph) in layout.flattenedRuns.enumerated() {
            // Calculate the sine wave offset for the current character
            let offset = animatedSineWaveOffset(
                forCharacterAt: index,
                amplitude: Double(height) / 2, // Set amplitude to half the line height
                wavelength: Double(width),
                phaseOffset: timeOffset,
                totalCharacters: count
            )
            // Create a copy of the context and translate it
            var copy = context
            copy.translateBy(x: 0, y: Float(offset))
            // Draw the current RunSlice in the modified context
            copy.draw(glyph)
        }

        func animatedSineWaveOffset(
            forCharacterAt index: Int,
            amplitude: Double,
            wavelength: Double,
            phaseOffset: Double,
            totalCharacters: Int
        ) -> Double {
            let x = Double(index)
            let position = (x / Double(totalCharacters)) * wavelength
            let radians = ((position + phaseOffset) / wavelength) * 2 * .pi
            return Math.sin(radians) * amplitude
        }
    }
}
