@component(id: "fixture.body")
struct Body {
    @export var y = 10.0;
    @export var speed = 0.0;
}

@system(id: "fixture.gravity")
class GravitySystem {
    @query(Body)
    var bodies;

    func update(context) {
        for (var entity in bodies) {
            entity.body.speed = clampSpeed(entity.body.speed - 9.8 * context.deltaTime);
            entity.body.y = entity.body.y + entity.body.speed * context.deltaTime;
        }
    }
}

private func clampSpeed(speed) {
    return Math.max(speed, -50.0);
}

func fallDistance(seconds) {
    return 0.5 * 9.8 * seconds * seconds;
}

@test("speed is capped")
func speedIsCapped() {
    expectEqual(clampSpeed(-100.0), -50.0);
    expectEqual(clampSpeed(-1.0), -1.0);
}
