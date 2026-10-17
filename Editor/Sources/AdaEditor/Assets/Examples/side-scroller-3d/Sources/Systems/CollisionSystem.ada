import { Config } from "../Config.ada";
import { Rules } from "../Rules.ada";
import { Cues } from "../Components/Cues.ada";
import { GameState } from "../Components/GameState.ada";
import { Obstacle } from "../Components/Obstacle.ada";
import { Player } from "../Components/Player.ada";

// Ends the round when the player touches an obstacle, the floor or the ceiling.
@after(id: "runner.obstacles")
@before(id: "runner.score")
@system(scheduler: "update", id: "runner.collision")
class CollisionSystem {
    @query(GameState, Cues) var games;
    @query(Player, Transform) var players;
    @query(Obstacle, Transform) var obstacles;

    func update(context) {
        var playing = false;
        for (var game in games) { playing = game.gameState.phase == Config.phasePlaying; }
        if (!playing) return;

        var crashed = false;
        for (var player in players) {
            var y = player.transform.position[1];
            if (Rules.outOfBounds(y)) { crashed = true; }
            for (var obstacle in obstacles) {
                if (Rules.hitsObstacle(y, obstacle.transform.position[0], obstacle.obstacle.gapY)) { crashed = true; }
            }
        }
        if (crashed) {
            for (var game in games) {
                game.gameState.phase = Config.phaseOver;
                if (game.gameState.score > game.gameState.best) { game.gameState.best = game.gameState.score; }
                game.cues.crash = true;
            }
        }
    }
}
