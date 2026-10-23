// Events of this frame that sound should react to, on the Game entity. Gameplay systems raise them,
// AudioSystem plays and clears them.
@component(id: "runner.cues")
struct Cues {
    @export var flap = false;
    @export var score = false;
    @export var crash = false;
}
