import AdaEngine

struct FirstScene: Plugin {
    func setup(in app: AppWorlds) {
        /** Collapsed code */
    }
}

@Component
struct PlayerComponent {}

@PlainSystem
func PlayerMovement(
    _ playerTransform: FIlterQuery<Ref<Transform>, With<PlayerComponent>>,
    _ speed: LocalIsolated<Float> = 3.0,
    _ deltaTime: ResQuery<DeltaTime>
) {
    if Input.isKeyPressed(.w) {
        playerTransform.position.y += speed.wrappedValue * deltaTime.wrappedValue.deltaTime
    }
}