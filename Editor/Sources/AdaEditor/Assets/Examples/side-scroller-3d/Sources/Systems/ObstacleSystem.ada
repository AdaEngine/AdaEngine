import { Config } from "../Config.ada";
import { Rules } from "../Rules.ada";
import { GameState } from "../Components/GameState.ada";
import { Obstacle } from "../Components/Obstacle.ada";

// Scrolls the obstacle pool left. A column that leaves the screen is moved to the back and gets a new gap,
// so the game never spawns or despawns obstacles while it runs.
@after(id: "runner.flight")
@before(id: "runner.collision")
@system(scheduler: "update", id: "runner.obstacles")
class ObstacleSystem {
    @query(GameState) var games;
    @query(Obstacle, Transform) var obstacles;

    func update(context) {
        var playing = false;
        var sequence = 0;
        for (var game in games) {
            playing = game.gameState.phase == Config.phasePlaying;
            sequence = game.gameState.nextSequence;
        }
        if (!playing) return;

        var dt = Rules.step(context.deltaTime);
        for (var row in obstacles) {
            var position = row.transform.position;
            var x = position[0] - Config.scrollSpeed * dt;
            if (x < Config.recycleX) {
                x += Config.obstacleCount * Config.obstacleSpacing;
                row.obstacle.gapY = Rules.gapFor(sequence);
                row.obstacle.passed = false;
                sequence += 1;
            }
            row.transform.position = [x, row.obstacle.gapY, position[2]];
        }
        for (var game in games) { game.gameState.nextSequence = sequence; }
    }
}
