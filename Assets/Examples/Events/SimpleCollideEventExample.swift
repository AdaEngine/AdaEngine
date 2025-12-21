//
//  SimpleCollideEventExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.12.2025.
//

import AdaEngine

@main
struct SimpleCollideEventExampleApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                SimpleCollideEventExamplePlugin()
            )
            .windowMode(.windowed)
    }
}

struct OnCollide: Event {
    let first: Entity.ID
    let second: Entity.ID
}

struct SimpleCollideEventExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        // Called first
        app.addSystem(ReceiverSystem.self, on: .update)

        // Called second
        app.addSystem(ColliderSystem.self, on: .postUpdate)
    }
}

@System
func Collider(
    _ sender: EventsSender<OnCollide>
) {
    /// short hand of sending event or use `sender.send(OnCollide...)`
    sender.send(OnCollide(first: .random(in: 0..<10), second: .random(in: 10..<20)))
}

@System
func ColliderShort(
    _ sender: EventsSender<OnCollide>
) {
    sender(OnCollide(first: .random(in: 0..<10), second: .random(in: 10..<20)))
}

@System
func ColliderMultiple(
    _ sender: EventsSender<OnCollide>
) {
    let events = [
        OnCollide(first: .random(in: 0..<10), second: .random(in: 10..<20)),
        OnCollide(first: .random(in: 0..<10), second: .random(in: 10..<20)),
        OnCollide(first: .random(in: 0..<10), second: .random(in: 10..<20))
    ]
    sender.send(events)
}

@System
func Receiver(
    _ events: Events<OnCollide>
) {
    for event in events {
        print("Receive collide event", event)
    }

    // list of events from previous frame
    print("Events", events.count)
    // list of current events in this frame
    print("Current events count", events.currentEvents.count)
}
