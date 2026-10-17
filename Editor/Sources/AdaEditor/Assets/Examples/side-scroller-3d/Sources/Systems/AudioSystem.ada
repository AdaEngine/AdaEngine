import { Rules } from "../Rules.ada";
import { Cues } from "../Components/Cues.ada";
import { SoundCue } from "../Components/SoundCue.ada";

// Plays the AudioSource entities whose SoundCue matches a cue raised this frame, then clears the cues.
// Each sound has its own entity because a second play() restarts the same source.
@after(id: "runner.score")
@system(scheduler: "update", id: "runner.audio")
class AudioSystem {
    @query(Cues) var games;
    @query(AudioSource, SoundCue) var sounds;

    func update(context) {
        var flap = false;
        var score = false;
        var crash = false;
        for (var game in games) {
            flap = game.cues.flap;
            score = game.cues.score;
            crash = game.cues.crash;
            game.cues.flap = false;
            game.cues.score = false;
            game.cues.crash = false;
        }
        for (var row in sounds) {
            if (Rules.shouldPlay(row.soundCue.name, flap, score, crash)) { row.audioSource.play = true; }
        }
    }
}
