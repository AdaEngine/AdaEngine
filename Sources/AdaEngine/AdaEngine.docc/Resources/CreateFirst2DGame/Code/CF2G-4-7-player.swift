import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        /** Collapsed code */
    }
}

@Component
struct PlayerComponent {}

@PlainSystem
func PlayerMovement(
    _ playerTransform: Query<Ref<Transform>, With<PlayerComponent>>,
    _ speed: LocalIsolated<Float> = 3.0,
    _ deltaTime: ResQuery<DeltaTime>
) {
    if Input.isKeyPressed(.w) {
        playerTransform.position.y += speed.wrappedValue * deltaTime.wrappedValue.deltaTime
    }

    if Input.isKeyPressed(.s) {
        playerTransform.position.y -= speed.wrappedValue * deltaTime.wrappedValue.deltaTime
    }
    
    if Input.isKeyPressed(.a) {
        playerTransform.position.x -= speed.wrappedValue * deltaTime.wrappedValue.deltaTime
    }
            
    if Input.isKeyPressed(.d) {
        playerTransform.position.x += speed.wrappedValue * deltaTime.wrappedValue.deltaTime
    }
}
