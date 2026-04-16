////
////  KeyframeSpritesExample.swift
////  AdaEngine
////
//
//import AdaEngine
//
//@main
//struct KeyframeSpritesExampleApp: App {
//    var body: some AppScene {
//        DefaultAppWindow()
//            .addPlugins(KeyframeSpritesExamplePlugin())
//            .windowMode(.windowed)
//            .windowTitle("Keyframe Sprites Example  [1] idle  [2] burst")
//    }
//}
//
//// MARK: - Animatable value structs
//
///// Drives Transform on the entity that owns the KeyframeAnimator.
//struct TransformAnim: KeyframeAnimatable {
//    var transform: Transform = .init()
//
//    func apply(to entityId: Entity.ID, in world: World) {
//        world.insert(transform, for: entityId)
//    }
//}
//
//// MARK: - Plugin
//
//struct KeyframeSpritesExamplePlugin: Plugin {
//    func setup(in app: AppWorlds) {
//        let texture = try! AssetsManager.loadSync(Texture2D.self, at: "Resources/dog.png", from: .module)
//
//        // Hero — white sprite, animates a bob up/down on idle
//        app.spawn("HeroSprite") {
//            Sprite(texture: texture, tintColor: .white)
//            Transform(scale: [1, 1, 1], position: [0, 0, 0])
//            heroAnimator()
//        }
//
//        // Companion — blue sprite, rocks side to side on idle
//        app.spawn("CompanionSprite") {
//            Sprite(texture: texture, tintColor: .blue)
//            Transform(scale: [0.7, 0.7, 1], position: [180, 0, 0])
//            companionAnimator()
//        }
//
//        app.spawn("DemoCamera", bundle: Camera2D())
//        
//        app.addSystem(KeyframeSpriteInputSystem.self)
//    }
//}
//
//// MARK: - Clip builders
//
//private func heroAnimator() -> KeyframeAnimator {
//    let initial = TransformAnim()
//
//    let idle = KeyframeClip(
//        name: "idle",
//        initialValues: initial,
//        duration: 2,
//        repeatMode: .loop(reversed: true)
//    ) {
//        // Bob up and back down
//        KeyframeTrack(\.transform.position) {
//            LinearKeyframe(Vector3(0, 25, 0), duration: 0.5, curve: .cubicInOut)
//            LinearKeyframe(Vector3(0, 0, 0), duration: 0.5, curve: .cubicInOut)
//            LinearKeyframe(Vector3(0, 25, 0), duration: 0.5, curve: .cubicInOut)
//            LinearKeyframe(Vector3(0, 0, 0), duration: 0.5, curve: .cubicInOut)
//        }
//    }
//
//    let burst = KeyframeClip(
//        name: "burst",
//        initialValues: initial,
//        duration: 1.5,
//        repeatMode: .loop(reversed: true)
//    ) {
//        // Pulse scale
//        KeyframeTrack(\.transform.scale) {
//            [
//            LinearKeyframe(Vector3(1, 1, 1), duration: 0.5, curve: .cubicInOut),
//            LinearKeyframe(Vector3(1.35, 1.35, 1), duration: 0.5, curve: .cubicInOut),
//            LinearKeyframe(Vector3(0.9, 0.9, 1), duration: 0.5, curve: .cubicInOut)
//            ]
//        }
//    }
//
//    return KeyframeAnimator {
//        idle
//        burst
//    }
//}
//
//private func companionAnimator() -> KeyframeAnimator {
//    let initial = TransformAnim(transform: Transform(scale: [0.7, 0.7, 1], position: [180, 0, 0]))
//
//    let idle = KeyframeClip(
//        name: "idle",
//        initialValues: initial,
//        duration: 2,
//        repeatMode: .loop(reversed: true)
//    ) {
//        // Rock left and right
//        KeyframeTrack(\.transform.rotation) {
//            LinearKeyframe(Quat(axis: [0, 0, 1], angle: -0.15), duration: 1)
//            LinearKeyframe(Quat(axis: [0, 0, 1], angle:  0.15), duration: 1)
//        }
//    }
//
//    let burst = KeyframeClip(
//        name: "burst",
//        initialValues: initial,
//        duration: 1.5,
//        repeatMode: .loop(reversed: true)
//    ) {
//        // Sweep across screen
//        KeyframeTrack(\.transform.position) {
//            LinearKeyframe(Vector3( 180, 0, 0), duration: 0.75)
//            LinearKeyframe(Vector3(-180, 0, 0), duration: 0.75)
//        }
//    }
//
//    return KeyframeAnimator {
//        idle
//        burst
//    }
//}
//
//// MARK: - Input system (switch clips with 1 / 2)
//
//@System
//func KeyframeSpriteInput(
//    _ input: Res<Input>,
//    _ animators: Query<Ref<KeyframeAnimator>>
//) {
//    let keyDown = input.wrappedValue
//        .getInputEvents()
//        .compactMap { $0 as? KeyEvent }
//        .filter { $0.status == .down && !$0.isRepeated }
//        .map(\.keyCode)
//    guard !keyDown.isEmpty else { return }
//
//    animators.forEach { animator in
//        var a = animator
//        for key in keyDown {
//            if key == .num1 {
//                a.playClip(by: "idle")
//            } else if key == .num2 {
//                a.playClip(by: "burst")
//            }
//        }
//    }
//}
