import { PlayerIntent } from "../Components/PlayerIntent.ada";

// The only system that reads the Input resource. Actions are declared in .ada/project.json.
// The binding is optional so TestWorld, which has no Input, can still run the whole schedule.
@before(id: "runner.phase")
@system(scheduler: "update", id: "runner.input")
class InputSystem {
    @res(optional: true) var input: Input;
    @query(PlayerIntent) var intents;

    func update(context) {
        if (!input.available()) return;
        for (var game in intents) {
            game.playerIntent.flap = input.isActionJustPressed("Flap");
            game.playerIntent.restart = input.isActionJustPressed("Restart");
        }
    }
}
