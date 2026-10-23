import { Config } from "../Sources/Config.ada";
import { Rules } from "../Sources/Rules.ada";
import { HudText } from "../Sources/UI/HudText.ada";

@test("gaps stay inside the allowed range and repeat deterministically")
func gapsAreBounded() {
    var i = 0;
    while (i < 40) {
        var gap = Rules.gapFor(i);
        expect(gap >= -Config.gapRange && gap <= Config.gapRange);
        expectEqual(gap, Rules.gapFor(i));
        i += 1;
    }
}

@test("floor and ceiling end the round")
func boundsCollide() {
    expect(!Rules.outOfBounds(0.0));
    expect(Rules.outOfBounds(Config.floorY));
    expect(Rules.outOfBounds(Config.ceilingY));
}

@test("an obstacle only hurts inside its column and outside its gap")
func obstacleCollision() {
    expect(!Rules.hitsObstacle(0.0, Config.playerX, 0.0));
    expect(Rules.hitsObstacle(2.0, Config.playerX, 0.0));
    expect(Rules.hitsObstacle(-2.0, Config.playerX, 0.0));
    expect(!Rules.hitsObstacle(2.0, Config.playerX + 5.0, 0.0));
}

@test("an obstacle scores exactly once")
func passScoresOnce() {
    expect(!Rules.hasPassed(Config.playerX + 1.0, false));
    expect(Rules.hasPassed(Config.playerX - 2.0, false));
    expect(!Rules.hasPassed(Config.playerX - 2.0, true));
}

@test("long frames are clamped")
func stepIsClamped() {
    expectEqual(Rules.step(1.0), Config.maxStep);
    expectNear(Rules.step(0.016), 0.016, 0.0001);
}

@test("cues select their own sound")
func cueRouting() {
    expect(Rules.shouldPlay("flap", true, false, false));
    expect(!Rules.shouldPlay("score", true, false, false));
    expect(Rules.shouldPlay("crash", false, false, true));
}

@test("the HUD explains each phase")
func hudWording() {
    expect(HudText.status(Config.phaseReady, 0, 0) == "READY");
    expect(HudText.status(Config.phasePlaying, 3, 0) == "");
    expect(HudText.status(Config.phaseOver, 3, 5) == "GAME OVER  BEST 5");
    expect(HudText.hint(Config.phaseOver) != "");
}
