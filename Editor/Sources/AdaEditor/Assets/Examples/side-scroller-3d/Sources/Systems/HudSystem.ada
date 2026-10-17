import { GameState } from "../Components/GameState.ada";
import { HudModel } from "../UI/HudModel.ada";
import { HudText } from "../UI/HudText.ada";

// Turns the round state into HUD text once per frame.
@after(id: "runner.score")
@system(scheduler: "update", id: "runner.hud-text")
class HudSystem {
    @query(GameState) var games;

    func update(context) {
        for (var game in games) {
            HudModel.score = "" + game.gameState.score;
            HudModel.status = HudText.status(game.gameState.phase, game.gameState.score, game.gameState.best);
            HudModel.hint = HudText.hint(game.gameState.phase);
        }
    }
}
