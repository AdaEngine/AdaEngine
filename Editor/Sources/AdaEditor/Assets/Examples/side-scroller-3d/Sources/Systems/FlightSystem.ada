import { Config } from "../Config.ada";
import { Rules } from "../Rules.ada";
import { Cues } from "../Components/Cues.ada";
import { GameState } from "../Components/GameState.ada";
import { Player } from "../Components/Player.ada";
import { PlayerIntent } from "../Components/PlayerIntent.ada";

// Flap impulse and gravity. Only runs while a round is playing.
@after(id: "runner.restart")
@before(id: "runner.obstacles")
@system(scheduler: "update", id: "runner.flight")
class FlightSystem {
    @query(GameState, PlayerIntent, Cues) var games;
    @query(Player, Transform) var players;

    func update(context) {
        var playing = false;
        var flap = false;
        for (var game in games) {
            playing = game.gameState.phase == Config.phasePlaying;
            flap = game.playerIntent.flap;
        }
        if (!playing) return;

        var dt = Rules.step(context.deltaTime);
        for (var row in players) {
            if (flap) { row.player.velocity = Config.flapSpeed; }
            row.player.velocity -= Config.gravity * dt;
            var position = row.transform.position;
            row.transform.position = [position[0], position[1] + row.player.velocity * dt, position[2]];
        }
        if (flap) {
            for (var game in games) { game.cues.flap = true; }
        }
    }
}
