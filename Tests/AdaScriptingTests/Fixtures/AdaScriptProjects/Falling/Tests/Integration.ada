import { fallDistance } from "../Systems/Gravity";

@test("a body falls about as far as the formula says")
func fallsLikeTheFormula() {
    var world = TestWorld();
    var body = world.spawn([Body(y: 100.0, speed: 0.0)]);
    world.run(60);
    var fallen = 100.0 - world.read(body, "Body", "y");
    expectNear(fallen, fallDistance(1.0), 0.5);
}
