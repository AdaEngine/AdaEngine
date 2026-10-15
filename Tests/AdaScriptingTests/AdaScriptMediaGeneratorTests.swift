import AdaAssets
@testable import AdaScripting
import Testing

@Suite("AdaScript sound and sprite generators", .serialized)
@MainActor
struct AdaScriptMediaGeneratorTests {
    @Test("Builds a layered sound effect with a pitch sweep, filter and echo")
    func generatesSound() throws {
        let audio = try AdaScriptSoundGenerator.generate(
            source: """
            func build(sound) {
                sound.rate(22050);
                sound.peak(0.7);
                var blip = sound.tone("square", sound.pitch(81), 0.12);
                sound.duty(blip, 0.25);
                sound.envelope(blip, 0.002, 0.08, 0.2);
                sound.sweep(blip, 1200.0);
                var hiss = sound.tone("noise", 6000, 0.1);
                sound.volume(hiss, 0.2);
                sound.highpass(hiss, 2000);
                sound.at(hiss, 0.05);
                sound.echo(0.08, 0.4, 0.3);
                var i = 0;
                while (i < 3) {
                    var note = sound.tone("sine", 440 * (i + 1), 0.05);
                    sound.at(note, 0.2 + i * 0.06);
                    sound.vibrato(note, 6.0, 0.3);
                    sound.lowpass(note, 3000);
                    i = i + 1;
                }
            }
            """
        )
        #expect(audio.sampleRate == 22_050 && audio.channels == 1)
        let report = AudioAnalyzer.analyze(audio)
        #expect(abs(report.peak - 0.7) < 0.001)
        #expect(report.duration > 0.4)
        #expect(report.leadingSilence < 0.01)

        let decoded = try WAVReader().decode(WAVWriter().encode(audio))
        #expect(decoded.frameCount == audio.frameCount)
    }

    @Test("MIDI helper follows equal temperament")
    func midiPitch() throws {
        // A4 = 69 is 440 Hz, so a voice at that pitch must be detected near 440.
        let audio = try AdaScriptSoundGenerator.generate(source: "func build(sound) { sound.tone(\"sine\", sound.pitch(69), 0.4); }")
        #expect(abs(AudioAnalyzer.analyze(audio).dominantFrequency - 440) < 15)
    }

    @Test("Rejects invalid sound scripts and arguments")
    func rejectsInvalidSounds() {
        let scripts = [
            "func build(sound) { }",
            "func build(sound) { sound.tone(\"banjo\", 440, 0.2); }",
            "func build(sound) { sound.tone(\"sine\", 0, 0.2); }",
            "func build(sound) { sound.tone(\"sine\", 440, 40.0); }",
            "func build(sound) { sound.tone(\"sine\", 440, 0.2, 0.5); sound.rate(100); }",
            "func build(sound) { sound.rate(100); sound.tone(\"sine\", 440, 0.2); }",
            "func build(sound) { sound.volume(3, 0.5); sound.tone(\"sine\", 440, 0.2); }",
            "func build(sound) { var v = sound.tone(\"sine\", 440, 0.2); sound.volume(v, 1.5); }",
            "func build(sound) { var v = sound.tone(\"sine\", 440, 0.2); sound.envelope(v, 0.0, 0.0, 2.0); }",
            "func build(sound) { var v = sound.tone(\"sine\", 440, 0.2); sound.volume(v, 0.0); }",
            "func build(sound) { sound.tone(\"sine\", 440, 0.2); sound.echo(0.0, 0.5, 0.5); }",
            "func build(sound) { var v = sound.tone(\"sine\", 440, 25.0); sound.at(v, 20.0); }",
            "func build(sound) { sound.pitch(200); sound.tone(\"sine\", 440, 0.2); }",
            "func build(sound) { sound.tone(\"sine\", 440, 0.2); System.exit(1); }",
            "func build(sound) { while (true) { } }",
        ]
        for script in scripts {
            #expect(throws: (any Error).self, "\(script)") { try AdaScriptSoundGenerator.generate(source: script) }
        }
    }

    @Test("Enforces the voice budgets")
    func soundBudgets() {
        let tooManyVoices = """
            func build(sound) {
                var i = 0;
                while (i < 300) { sound.tone("sine", 440, 0.05); i = i + 1; }
            }
            """
        #expect(throws: (any Error).self) { try AdaScriptSoundGenerator.generate(source: tooManyVoices) }
        let tooMuchSynthesis = """
            func build(sound) {
                var i = 0;
                while (i < 8) { sound.tone("sine", 440, 20.0); i = i + 1; }
            }
            """
        #expect(throws: (any Error).self) { try AdaScriptSoundGenerator.generate(source: tooMuchSynthesis) }
    }

    @Test("Paints a symmetric outlined sprite with a translucent palette entry")
    func generatesSprite() throws {
        let result = try AdaScriptSpriteGenerator.generate(
            source: """
            func build(sprite) {
                sprite.size(16, 16);
                sprite.palette(1, 220, 60, 50);
                sprite.palette(2, 20, 20, 30);
                sprite.palette(3, 0, 0, 0);
                sprite.opacity(3, 100);
                sprite.ellipse(5, 8, 4, 5, 1);
                sprite.rect(2, 12, 7, 13, 2);
                sprite.line(0, 0, 7, 0, 2);
                sprite.circle(4, 5, 1, 3);
                sprite.pixel(3, 3, 3);
                sprite.mirror();
                sprite.outline(2);
            }
            """
        )
        let canvas = result.canvas
        #expect((canvas.width, canvas.height) == (16, 16))
        #expect(canvas.palette[1] == PixelColor(red: 220, green: 60, blue: 50))
        #expect(canvas.palette[3].alpha == 100)
        for y in 0..<16 {
            for x in 0..<8 {
                // The outline runs after mirroring, so compare the interior only.
                if canvas.color(x: x, y: y) == 1 { #expect(canvas.color(x: 15 - x, y: y) == 1) }
            }
        }
        #expect(canvas.usedColors.contains(1) && canvas.usedColors.contains(2))
        let png = try PNGWriter().encode(width: canvas.width, height: canvas.height, rgba: canvas.rgba())
        #expect(png.count > 100)
    }

    @Test("Rejects invalid sprite scripts and arguments")
    func rejectsInvalidSprites() {
        let scripts = [
            "func build(sprite) { }",
            "func build(sprite) { sprite.size(8, 8); }",
            "func build(sprite) { sprite.pixel(0, 0, 1); }",
            "func build(sprite) { sprite.size(0, 8); }",
            "func build(sprite) { sprite.size(600, 8); }",
            "func build(sprite) { sprite.size(8, 8); sprite.size(8, 8); sprite.pixel(0, 0, 1); }",
            "func build(sprite) { sprite.size(8, 8); sprite.pixel(0.5, 0, 1); }",
            "func build(sprite) { sprite.size(8, 8); sprite.pixel(0, 0, 300); }",
            "func build(sprite) { sprite.size(8, 8); sprite.palette(0, 1, 2, 3); sprite.pixel(0, 0, 1); }",
            "func build(sprite) { sprite.size(8, 8); sprite.palette(1, 1, 2, 300); sprite.pixel(0, 0, 1); }",
            "func build(sprite) { sprite.size(8, 8); sprite.pixel(1, 1, 1); sprite.outline(0); }",
            "func build(sprite) { sprite.size(8, 8); sprite.circle(4, 4, -1, 1); }",
            "func build(sprite) { sprite.size(8, 8); sprite.pixel(0, 0, 1); System.exit(1); }",
            "func build(sprite) { while (true) { } }",
        ]
        for script in scripts {
            #expect(throws: (any Error).self, "\(script)") { try AdaScriptSpriteGenerator.generate(source: script) }
        }
    }
}
