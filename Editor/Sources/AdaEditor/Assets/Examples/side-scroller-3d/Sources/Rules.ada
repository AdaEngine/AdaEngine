import { Config } from "./Config.ada";

// Pure gameplay rules. No ECS access, so tests call them directly.
class Rules {
    // Deterministic gap height for the nth obstacle, between -gapRange and +gapRange.
    static func gapFor(sequence) {
        var step = (sequence * 7) % 9 - 4;
        return step * Config.gapRange / 4.0;
    }

    static func outOfBounds(y) {
        return y - Config.playerRadius < Config.floorY || y + Config.playerRadius > Config.ceilingY;
    }

    // True when a player at height y touches the obstacle column at obstacleX whose gap is centred on gapY.
    static func hitsObstacle(y, obstacleX, gapY) {
        var reach = Config.obstacleHalfWidth + Config.playerRadius;
        var dx = obstacleX - Config.playerX;
        if (dx > reach || dx < -reach) return false;
        var margin = Config.gapHalfHeight - Config.playerRadius;
        return y > gapY + margin || y < gapY - margin;
    }

    // An obstacle scores once, when its column has fully passed the player.
    static func hasPassed(obstacleX, alreadyPassed) {
        return !alreadyPassed && obstacleX + Config.obstacleHalfWidth < Config.playerX - Config.playerRadius;
    }

    static func step(deltaTime) {
        return Math.clamp(deltaTime, 0.0, Config.maxStep);
    }

    // Which AudioSource entity (by SoundCue name) should play for the cues raised this frame.
    static func shouldPlay(name, flap, score, crash) {
        return (name == "flap" && flap) || (name == "score" && score) || (name == "crash" && crash);
    }
}
