// Round state. It lives on one "Game" entity in the scene: Studio AdaScript projects keep shared data in
// components, because @resource declarations are not available there.
@component(id: "runner.state")
struct GameState {
    @export var phase = 0;
    @export var score = 0;
    @export var best = 0;
    @export var nextSequence = 0;
    @export var resetRequested = true;
}
