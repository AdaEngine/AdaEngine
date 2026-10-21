// Regenerate with python3 script/generate_shader_graph_fixture.py --gravity /path/to/host/gravity.
@system(id: "aot.shader-graph", scheduler: "shaderGraphTest")
@access(write: [Sprite])
class ShaderGraphControl {
    @query(Sprite) var sprites;
    func update(context) {
        for (var row in sprites) {
            var graph = row.sprite.shader(0);
            var valid = graph.parameterType("tint") == "color";
            valid = valid && graph.parameterName("tint") == "Tint";
            valid = valid && graph.parameterIDs()[0] == "enabled";
            valid = valid && graph.getFloat("Amount") == 0.5;
            valid = graph.setColor("tint", [0.25, 0.5, 1.0, 1.0]) && valid;
            valid = graph.setFloat("gain", 0.75) && valid;
            valid = graph.setBool("enabled", false) && valid;
            valid = valid && graph.getColor("tint")[0] == 0.25;
            valid = valid && graph.getFloat("gain") == 0.75;
            valid = valid && graph.getBool("enabled") == false;
            if (!valid) { graph.setFloat("gain", -1.0); }
        }
    }
}
class ShaderGraphProbe {
    var saved = null;
    func mutate(component) { return component.shader(0).setFloat("gain", 1.0); }
    func remember(component) { saved = component.shader(0); }
    func useSaved() { return saved.setFloat("gain", 1.0); }
}
@scriptable(id: "shader.graph.controller", version: 1)
class ShaderGraphController {
    @component(Sprite) var sprite: Sprite;
    func ready(context) { sprite.shader(0).setFloat("gain", 0.125); }
}
