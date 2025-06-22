import AdaEngine

struct FirstScene: Plugin {
    func setup(in app: AppWorlds) {
        /** Collapsed code */
    }
}

@Component
struct PlayerComponent {}

@System
func PlayerMovement(
    _ playerTransform: FIlterQuery<Ref<Transform>, With<PlayerComponent>>,
    _ speed: Local<Float> = 3.0
) {
    
}
