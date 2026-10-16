// What the player asked for this frame, on the Game entity. Only InputSystem touches the Input resource;
// everything else reads this component, which also lets tests press keys.
@component(id: "runner.intent")
struct PlayerIntent {
    @export var flap = false;
    @export var restart = false;
}
