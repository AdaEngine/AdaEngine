// The text the HUD shows. HudSystem writes it from the round state; the Hud scriptable only copies it into the
// fields bound to Assets/UI/Hud.ui. A scriptable cannot bind script-defined components in Studio, so this
// small presentation model is the one place that is not a component. Gameplay never reads it.
class HudModel {
    static var score = "0";
    static var status = "READY";
    static var hint = "";
}
