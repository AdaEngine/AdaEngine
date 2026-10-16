import { Config } from "../Sources/Config.ada";
import { Cues } from "../Sources/Components/Cues.ada";
import { GameState } from "../Sources/Components/GameState.ada";
import { Obstacle } from "../Sources/Components/Obstacle.ada";
import { Player } from "../Sources/Components/Player.ada";
import { PlayerIntent } from "../Sources/Components/PlayerIntent.ada";
import { SoundCue } from "../Sources/Components/SoundCue.ada";
import { HudModel } from "../Sources/UI/HudModel.ada";

// TestWorld has no Input resource, so these tests press keys by replacing the PlayerIntent component on the Game entity.
var gameEntity = 0;

func startRound(world) {
    gameEntity = world.spawn([GameState(), PlayerIntent(), Cues()]);
    var player = world.spawn([Player(), Transform()]);
    var slot = 0;
    while (slot < Config.obstacleCount) {
        world.spawn([Obstacle(slot: slot), Transform()]);
        slot += 1;
    }
    tick(world, 1);
    return player;
}

// One tick is 1/60 s. run() installs every system; InputSystem finds no Input resource here and leaves
// the PlayerIntent component alone, so the tests press keys by replacing it.
func tick(world, count) {
    world.run(count);
}

func press(world, flap, restart) {
    world.insert(gameEntity, PlayerIntent(flap: flap, restart: restart));
    tick(world, 1);
    world.insert(gameEntity, PlayerIntent());
}

func phase(world) { return world.read(gameEntity, "GameState", "phase"); }

@test("the first frame places the player and the obstacle pool")
func firstFrameResets() {
    var world = TestWorld();
    var player = startRound(world);
    expectEqual(phase(world), Config.phaseReady);
    expectEqual(world.read(player, "Player", "velocity"), 0.0);
    expectEqual(world.count("Obstacle"), Config.obstacleCount);
    expect(!world.read(gameEntity, "GameState", "resetRequested"));
}

@test("a flap starts the round and gravity pulls the player down again")
func flapAndFall() {
    var world = TestWorld();
    var player = startRound(world);
    press(world, true, false);
    expectEqual(phase(world), Config.phasePlaying);
    press(world, true, false);
    expect(world.read(player, "Player", "velocity") > 0.0);
    tick(world, 30);
    expect(world.read(player, "Player", "velocity") < 0.0);
}

@test("falling to the floor ends the round and a flap resets it")
func fallingEndsTheRound() {
    var world = TestWorld();
    var player = startRound(world);
    press(world, true, false);
    var frames = 0;
    while (frames < 120 && phase(world) == Config.phasePlaying) {
        tick(world, 1);
        frames += 1;
    }
    expectEqual(phase(world), Config.phaseOver);
    expectEqual(world.read(gameEntity, "GameState", "best"), 0);
    expect(HudModel.status != "READY");
    expect(HudModel.hint != "");
    press(world, true, false);
    expectEqual(phase(world), Config.phaseReady);
    expect(HudModel.status == "READY");
    expectEqual(world.read(gameEntity, "GameState", "score"), 0);
    expectNear(world.read(player, "Player", "velocity"), 0.0, 0.0001);
}

@test("R resets a round in progress")
func restartKey() {
    var world = TestWorld();
    startRound(world);
    press(world, true, false);
    expectEqual(phase(world), Config.phasePlaying);
    press(world, false, true);
    expectEqual(phase(world), Config.phaseReady);
}

@test("passing an obstacle scores once and raises the score cue")
func scoring() {
    var world = TestWorld();
    startRound(world);
    // A column already behind the player: it must score exactly once.
    world.spawn([Obstacle(slot: 9, gapY: 0.0), Transform(position: [-4.0, 0.0, 0.0])]);
    press(world, true, false);
    expectEqual(world.read(gameEntity, "GameState", "score"), 1);
    tick(world, 1);
    expectEqual(world.read(gameEntity, "GameState", "score"), 1);
    expectEqual(phase(world), Config.phasePlaying);
}

@test("a flap plays the flap sound")
func flapPlaysSound() {
    var world = TestWorld();
    startRound(world);
    var sound = world.spawn([AudioSource(source: "@res://Audio/flap.wav"), SoundCue(name: "flap")]);
    tick(world, 2);
    expect(!world.read(sound, "AudioSource", "play"));
    press(world, true, false);
    expect(world.read(sound, "AudioSource", "play"));
}
