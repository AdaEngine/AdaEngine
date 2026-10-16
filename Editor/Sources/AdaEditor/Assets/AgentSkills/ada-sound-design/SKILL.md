---
name: ada-sound-design
description: Synthesize sound effects and short music loops as WAV files from an AdaScript program in Ada Studio, check them with measurements, and play them in a game with the AudioSource component.
allowed-tools: editor.project.context, editor.audio.generate, editor.audio.inspect, editor.components.describe, editor.scene.get, editor.scene.apply, editor.docs.read, editor.examples.read, editor.build.start, editor.play.start, editor.task.status
---

# Ada Studio Sound Design

Use this to give a game its sound without external tools or providers: jumps, hits, pickups, UI clicks, lasers, explosions, engine hums, ambience and short chiptune loops. Describe the sound in AdaScript and Studio writes a `.wav`. Realistic voices, recorded instruments and finished music need an audio generation provider, which Studio does not have yet; say so instead of promising them.

1. Read `editor.project.context` for the Assets root. Choose a new destination such as `Assets/Audio/jump.wav`; `editor.audio.generate` never overwrites, so use a new name for each revision.
2. Call `editor.audio.generate` with `source` and `destination`. The script runs in an isolated VM: no files, network, scene or engine access, a 64 KiB source limit and a small time/step budget. Errors come back as text; fix the script and call again.
3. Read the measurements it returns and compare them with the intent (see Verify). You cannot listen, so the numbers are your ears: pitch, brightness, loudness shape and tail.
4. Read `editor.components.describe` with query `AudioSource`, add that component (and a Transform) to an entity in the scene, and set `source` to the returned `assetReference`. Preserve unrelated payload fields and pass the current scene revision.
5. Build, run visible Play and check the game still behaves. Audio is not captured in frames: report that playback was configured and measured, not that it was heard.

## Script API

Define `func build(sound)`. Times are seconds, frequencies Hz. `sound.tone` returns a voice id; configure the voice with the calls below and keep the id in a variable. A failed call records the error and generation is rejected with that message.

| Call | Meaning |
| --- | --- |
| `sound.tone(wave, hz, seconds)` | Add a voice. `wave` is `"sine"`, `"square"`, `"saw"`, `"triangle"` or `"noise"`. For noise `hz` sets how fast it changes: low is rumble, high is hiss. |
| `sound.at(id, start)` | Start time of the voice. Voices play together unless offset. |
| `sound.volume(id, 0...1)` | Voice level before the final scaling. |
| `sound.envelope(id, attack, decay, sustain)` | ADSR: seconds to ramp up, seconds to fall to the sustain level (0...1). Defaults: 0.005, 0, 1. |
| `sound.release(id, seconds)` | Fade-out after the voice ends (default 0.02, which prevents clicks). |
| `sound.sweep(id, endHz)` | Glide the pitch exponentially to `endHz` over the voice. Falling sweeps are impacts and lasers; rising sweeps are pickups and power-ups. |
| `sound.vibrato(id, rateHz, semitones)` | Pitch wobble. |
| `sound.duty(id, 0.05...0.95)` | Pulse width of a square wave; narrow pulses sound thin and nasal. |
| `sound.lowpass(id, hz)` / `sound.highpass(id, hz)` | Remove highs or lows. |
| `sound.echo(delay, feedback, mix)` | Repeats for the whole sound; `feedback` up to 0.9. The tail adds to the duration. |
| `sound.pitch(midi)` | Frequency of a MIDI note (69 is A4 = 440 Hz); use it to write melodies. |
| `sound.rate(hz)` | Sample rate 8000...48000 (default 44100). Lower rates sound crunchy and make smaller files. |
| `sound.peak(level)` | Loudest sample after rendering, 0.01...1 (default 0.9). Every sound is normalized to this, so set lower values for quiet effects instead of quiet voices. |
| `sound.seed(n)` | Seed for noise, so a sound is repeatable. |

Limits: 30 seconds, 256 voices, 120 voice-seconds of synthesis in total. Output is mono 16-bit.

## Recipes

```
func build(sound) {            // jump: short rising square blip
    var v = sound.tone("square", 260, 0.16);
    sound.duty(v, 0.25);
    sound.sweep(v, 620);
    sound.envelope(v, 0.002, 0.12, 0.0);
}
```

```
func build(sound) {            // coin: two quick notes a fifth apart
    var a = sound.tone("square", sound.pitch(83), 0.07);
    var b = sound.tone("square", sound.pitch(90), 0.22);
    sound.at(b, 0.07);
    sound.envelope(b, 0.002, 0.2, 0.0);
    sound.volume(a, 0.7);
}
```

```
func build(sound) {            // explosion: filtered noise burst with a low thump
    var n = sound.tone("noise", 900, 0.7);
    sound.lowpass(n, 1200);
    sound.envelope(n, 0.005, 0.6, 0.0);
    var t = sound.tone("sine", 90, 0.5);
    sound.sweep(t, 35);
    sound.envelope(t, 0.002, 0.4, 0.0);
    sound.seed(7);
}
```

```
func build(sound) {            // laser: falling saw with a little echo
    var v = sound.tone("saw", 1400, 0.25);
    sound.sweep(v, 180);
    sound.envelope(v, 0.002, 0.2, 0.0);
    sound.lowpass(v, 5000);
    sound.echo(0.09, 0.3, 0.25);
}
```

A loop for music is a melody written with `sound.pitch` and `sound.at` in a `while` loop, over a bass voice; keep it to 4-16 seconds and make the last note end before the final second so it can loop. Compose from a scale (for example minor pentatonic: 0, 3, 5, 7, 10 semitones above the root) so any order sounds right.

## Verify

`editor.audio.generate` and `editor.audio.inspect` return `durationSeconds`, `peak`, `rmsDBFS`, `clippedSamples`, `dcOffset`, `leadingSilenceSeconds`, `trailingSilenceSeconds`, `dominantFrequencyHz`, `spectralCentroidHz` and `loudnessEnvelopeDBFS` (ten slices from start to end).

- Sound effects: 0.05-1.2 s, `leadingSilenceSeconds` below 0.01 so the effect fires instantly, `clippedSamples` 0, `dcOffset` near 0.
- A hit or jump should be loud at the start and fall: the first envelope values clearly above the last. A pickup or UI sound is bright (`spectralCentroidHz` above about 1500); a rumble or engine is dark (below about 400).
- Ambience and music loops: steady envelope without a quiet tail so the loop point does not pump, and `trailingSilenceSeconds` below 0.05.
- If the sound is too long, too quiet at the end or the wrong pitch, change the script and generate under a new name; do not keep several near-identical files.

## Playing sounds in the game

`AudioSource` plays a sound from its entity's position. `source` is the `@res://` path; `autoplay` starts it once on load; `loops` repeats it; `volume` is 0...1. Distance to the active camera's listener lowers the volume, so put music and interface sounds on the camera entity (or any entity that moves with it) and positional effects on the object that makes them.

A script triggers an effect by setting `play` to `true`; the engine restarts the sound and clears the flag. Set `stop` to end it. Use one AudioSource entity per sound that can overlap itself, because a second `play` restarts the first.

```
@query(AudioSource, with: JumpSound)
var jumps;

func update() {
    if (Input.isKeyPressed(Key.space)) {
        for (var entity in jumps) { entity.audioSource.play = true; }
    }
}
```

Check the exact query and input syntax with `editor.docs.search` and `editor.examples.read`; the structure above is what matters. Keep a short note of every generated sound (path, purpose, where it plays) in the project's progress notes.
