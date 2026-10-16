// One reusable obstacle column. The pair of pipe meshes are children of this entity in the scene.
@component(id: "runner.obstacle")
struct Obstacle {
    @export var slot = 0;
    @export var gapY = 0.0;
    @export var passed = false;
}
