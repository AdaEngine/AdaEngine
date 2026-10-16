import { Config } from "../Config.ada";
import { Rules } from "../Rules.ada";
import { Cues } from "../Components/Cues.ada";
import { GameState } from "../Components/GameState.ada";
import { Obstacle } from "../Components/Obstacle.ada";

// One point for every obstacle the player gets past.
@after(id: "runner.collision")
@before(id: "runner.audio")
@system(scheduler: "update", id: "runner.score")
class ScoreSystem {
    @query(GameState, Cues) var games;
    @query(Obstacle, Transform) var obstacles;

    func update(context) {
        var playing = false;
        for (var game in games) { playing = game.gameState.phase == Config.phasePlaying; }
        if (!playing) return;

        var passed = 0;
        for (var row in obstacles) {
            if (Rules.hasPassed(row.transform.position[0], row.obstacle.passed)) {
                row.obstacle.passed = true;
                passed += 1;
            }
        }
        if (passed > 0) {
            for (var game in games) {
                game.gameState.score += passed;
                game.cues.score = true;
            }
        }
    }
}
