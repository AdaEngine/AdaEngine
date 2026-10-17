// The controlled body. Its position is the entity's Transform; only the extra state lives here.
@component(id: "runner.player")
struct Player {
    @export var velocity = 0.0;
}
