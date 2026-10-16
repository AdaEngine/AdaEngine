import { Config } from "../Config.ada";

// Pure text for the HUD, so wording can be tested without a window.
class HudText {
    static func status(phase, score, best) {
        if (phase == Config.phaseReady) return "READY";
        if (phase == Config.phaseOver) return "GAME OVER  BEST " + best;
        return "";
    }

    static func hint(phase) {
        if (phase == Config.phaseReady) return "SPACE OR CLICK TO FLAP";
        if (phase == Config.phaseOver) return "SPACE OR CLICK TO RETRY - R RESTARTS";
        return "";
    }
}
