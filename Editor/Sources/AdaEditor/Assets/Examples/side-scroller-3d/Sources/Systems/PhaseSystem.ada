import { Config } from "../Config.ada";
import { GameState } from "../Components/GameState.ada";
import { PlayerIntent } from "../Components/PlayerIntent.ada";

// Ready -> Playing -> Over -> Ready. Leaving Over (or pressing R) asks RestartSystem to reset the round.
@after(id: "runner.input")
@before(id: "runner.restart")
@system(scheduler: "update", id: "runner.phase")
class PhaseSystem {
    @query(GameState, PlayerIntent) var games;

    func update(context) {
        for (var game in games) {
            if (game.gameState.phase == Config.phaseReady && game.playerIntent.flap) {
                game.gameState.phase = Config.phasePlaying;
            }
            if (game.gameState.phase == Config.phaseOver && game.playerIntent.flap) {
                game.gameState.resetRequested = true;
            }
            if (game.playerIntent.restart) {
                game.gameState.resetRequested = true;
            }
        }
    }
}
