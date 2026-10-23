@system(id: "shader.smoke", scheduler: "update")
@access(write: [Sprite])
class ShaderSmoke {
    @query(Sprite) var sprites;
    func update(context) {
        for (var row in sprites) {
            row.sprite.shader(0).setColor("tint", [1.0, 0.4, 0.2, 1.0]);
        }
    }
}
