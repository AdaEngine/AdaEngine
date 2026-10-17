// Marks an AudioSource entity with the name of the cue that plays it ("flap", "score" or "crash").
@component(id: "runner.sound-cue")
struct SoundCue {
    @export var name = "";
}
