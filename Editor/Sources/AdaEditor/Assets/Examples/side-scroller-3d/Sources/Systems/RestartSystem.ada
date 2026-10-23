import { Config } from "../Config.ada";
import { Rules } from "../Rules.ada";
import { GameState } from "../Components/GameState.ada";
import { Obstacle } from "../Components/Obstacle.ada";
import { Player } from "../Components/Player.ada";

// Puts the round back to its start. Runs once for every reset request, including the one at launch.
@after(id: "runner.phase")
@before(id: "runner.flight")
@system(scheduler: "update", id: "runner.restart")
class RestartSystem {
    @query(GameState) var games;
    @query(Player, Transform) var players;
    @query(Obstacle, Transform) var obstacles;

    func update(context) {
        var requested = false;
        for (var game in games) { requested = game.gameState.resetRequested; }
        if (!requested) return;

        for (var row in players) {
            row.player.velocity = 0.0;
            row.transform.position = [Config.playerX, Config.playerStartY, 0.0];
        }
        for (var row in obstacles) {
            var gap = Rules.gapFor(row.obstacle.slot);
            row.obstacle.gapY = gap;
            row.obstacle.passed = false;
            row.transform.position = [Config.obstacleStartX + row.obstacle.slot * Config.obstacleSpacing, gap, 0.0];
        }
        for (var game in games) {
            game.gameState.phase = Config.phaseReady;
            game.gameState.score = 0;
            game.gameState.nextSequence = Config.obstacleCount;
            game.gameState.resetRequested = false;
        }
    }
}
