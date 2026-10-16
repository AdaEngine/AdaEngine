# Audio

AdaEngine plays WAV, MP3 and FLAC files through `AudioResource`. The design of the sound and asset tooling is in
[ADR-0026](ArchitectureDecisions/0026-scripted-asset-generation-and-autonomous-studio.md).

## Playing a sound from a scene

`AudioSource` is a serializable component, so scenes, the Studio inspector and scripts all use the same data:

| Field | Meaning |
| --- | --- |
| `source` | `@res://` path to a WAV, MP3 or FLAC file. |
| `volume` | Linear gain, 0 to 1. |
| `loops` | Repeat the sound until stopped. |
| `autoplay` | Play once as soon as the sound has loaded. |
| `play` | Request: start or restart the sound. The engine clears it. |
| `stop` | Request: stop the sound. The engine clears it. |

```swift
app.spawn("Jump sound") {
    AudioSource(source: "@res://Audio/jump.wav")
    Transform()
}
```

`AudioSourceSystem` (installed by `AudioPlugin`) loads the file, plays it from the entity's position and applies
`volume` and `loops` every update. A file that cannot be loaded sets `AudioSourceState.error` instead of
failing the game. Removing the component stops the sound.

A script plays an effect by setting `play`:

```ada
@query(AudioSource, with: JumpSound)
var jumps;

func update() {
    for (var entity in jumps) { entity.audioSource.play = true; }
}
```

Sound is spatial: the distance to the audio listener, which sits on the active camera, lowers the volume. Put
music and interface sounds on the camera entity. A second `play` restarts the same sound, so use one
`AudioSource` entity per sound that may overlap itself.

For Swift code that needs direct control, `Entity.playAudio(_:)` and `AudioPlaybackController` remain available.

## Generated sounds

Studio's agent can synthesize WAV files from an AdaScript program (`editor.audio.generate`) and measure any WAV
(`editor.audio.inspect`). The same synthesizer and analyzer are available in Swift as `SoundSynth`,
`WAVWriter`, `WAVReader` and `AudioAnalyzer` in `AdaAssets`:

```swift
var spec = SoundSpec()
var blip = SoundVoice(wave: .square, frequency: 260, duration: 0.16)
blip.endFrequency = 620
blip.decay = 0.12
blip.sustain = 0
spec.voices = [blip]
let wav = try WAVWriter().encode(SoundSynth.render(spec))
let report = AudioAnalyzer.analyze(try WAVReader().decode(wav))   // peak, loudness, pitch, silence
```
