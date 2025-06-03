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
    _ speed: LocalIsolated<Float> = 3.0
) {
    
}