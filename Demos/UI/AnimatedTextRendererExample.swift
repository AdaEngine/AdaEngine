//
//  AnimatedTextRendererApp.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.12.2025.
//

import AdaEngine
import Foundation

@main
struct AnimatedTextRendererApp: App {
    var body: some AppScene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Text("Some wave")
                .textRendered(
                    AnimatedSineWaveOffsetRender(
                        timeOffset: Self.phaseOffset(for: context.date)
                    )
                )
        }
    }

    private static func phaseOffset(for date: Date) -> Double {
        (date.timeIntervalSinceReferenceDate * 4).truncatingRemainder(dividingBy: 2 * .pi)
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
    var timeOffset: Double

    init(timeOffset: Double) {
        self.timeOffset = timeOffset
    }

    var animatableData: Double {
        get { timeOffset }
        set { timeOffset = newValue }
    }

    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        let count = layout.flattenedRuns.count
        let height = layout.first?.typographicBounds.rect.height ?? 0

        for (index, glyph) in layout.flattenedRuns.enumerated() {
            let offset = animatedSineWaveOffset(
                forCharacterAt: index,
                amplitude: Double(height) / 2,
                phaseOffset: timeOffset,
                totalCharacters: count
            )

            var copy = context
            copy.translateBy(x: 0, y: Float(offset))
            copy.draw(glyph)
        }

        func animatedSineWaveOffset(
            forCharacterAt index: Int,
            amplitude: Double,
            phaseOffset: Double,
            totalCharacters: Int
        ) -> Double {
            guard totalCharacters > 0 else {
                return 0
            }

            let position = Double(index) / Double(totalCharacters)
            let radians = position * 2 * .pi + phaseOffset
            return Math.sin(radians) * amplitude
        }
    }
}
