import { HudModel } from "./HudModel.ada";

// Feeds Assets/UI/Hud.ui. The scene's UIComponent binds each .ui input to one exported field below.
@scriptable(id: "runner.hud")
class Hud {
    @export var score = "0";
    @export var status = "READY";
    @export var hint = "";

    func update(context) {
        score = HudModel.score;
        status = HudModel.status;
        hint = HudModel.hint;
    }
}
